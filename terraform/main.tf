terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for the ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "juice_shop" {
  name        = "${var.project_name}-juice-shop-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.juice_shop.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "juice_shop" {
  family                   = "${var.project_name}-juice-shop-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "juice-shop"
      image     = var.juice_shop_image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# --- Athena for WAF Log Analysis ---

resource "aws_athena_database" "waf_analytics" {
  name   = "${var.project_name}_waf_logs"
  bucket = aws_s3_bucket.waf_logs.id
}

resource "aws_athena_table" "waf_logs" {
  name    = "waf_logs"
  bucket  = aws_s3_bucket.waf_logs.id
  database = aws_athena_database.waf_analytics.name

  schema {
    columns = [
      {
        name = "timestamp"
        type = "bigint"
      },
      {
        name = "formatversion"
        type = "int"
      },
      {
        name = "webaclid"
        type = "string"
      },
      {
        name = "terminatingruleid"
        type = "string"
      },
      {
        name = "terminatingruletype"
        type = "string"
      },
      {
        name = "action"
        type = "string"
      },
      {
        name = "terminatingrulematchdetails"
        type = "array<struct<conditiontype:string,location:string,matcheddata:array<string>>>"
      },
      {
        name = "https_source_name"
        type = "string"
      },
      {
        name = "https_source_id"
        type = "string"
      },
      {
        name = "rulegrouplist"
        type = "array<struct<rulegroupid:string,terminatingrule:struct<ruleid:string,action:string,rulematchdetails:string>,nonterminatingmatchingrules:array<string>,excludedrules:string>>"
      },
      {
        name = "ratebasedrulelist"
        type = "array<struct<ratebasedruleid:string,count:int,limitkey:string,maxrateallowed:int>>"
      },
      {
        name = "nonterminatingmatchingrules"
        type = "array<struct<ruleid:string,action:string>>"
      },
      {
        name = "requestheadersinserted"
        type = "string"
      },
      {
        name = "responsecodesent"
        type = "string"
      },
      {
        name = "httprequest"
        type = "struct<clientip:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpversion:string,httpmethod:string,requestid:string>"
      },
      {
        name = "labels"
        type = "array<struct<name:string>>"
      }
    ]
  }

  serde_info {
    name                  = "org.openx.data.jsonserde.JsonSerDe"
    serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    parameters = {
      "ignore.malformed.json" = "true"
    }
  }

  partition_keys = [
    {
      name = "date"
      type = "string"
    }
  ]
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Service
resource "aws_ecs_service" "juice_shop" {
  name            = "${var.project_name}-juice-shop-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.juice_shop.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.juice_shop.arn
    container_name   = "juice-shop"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http]
}

# --- CloudFront Distribution ---

data "archive_file" "security_headers_lambda" {
  type        = "zip"
  source_dir  = "../lambda/security-headers"
  output_path = "${path.module}/security-headers-lambda.zip"
}

resource "aws_iam_role" "lambda_edge" {
  name = "${var.project_name}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "security_headers" {
  function_name = "${var.project_name}-security-headers"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_edge.arn
  filename      = data.archive_file.security_headers_lambda.output_path
  source_code_hash = data.archive_file.security_headers_lambda.output_base64sha256
  publish       = true
}

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for Juice Shop"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["*"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    lambda_function_association {
      event_type   = "viewer-response"
      lambda_arn   = aws_lambda_function.security_headers.qualified_arn
      include_body = false
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

module "edge_waf" {
  source       = "./modules/edge_waf"
  project_name = var.project_name
  scope        = "CLOUDFRONT"
  resource_arn = aws_cloudfront_distribution.main.arn
  # Note: Logging for CloudFront WAF requires a Kinesis stream in us-east-1.
  # This is a more advanced setup requiring a separate provider configuration.
  # Disabling for now to keep the example clean.
  log_destination_arn = null

  custom_rules = [
    {
      name       = "AutoBlockListRule"
      priority   = 0
      ip_set_arn = aws_wafv2_ip_set.auto_block_list.arn
    }
  ]
}

# --- Self-Defending WAF Components ---

# 1. Dedicated IP set for auto-blocking
resource "aws_wafv2_ip_set" "auto_block_list" {
  name               = "${var.project_name}-auto-block-list"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = []
}

# 2. Add a rule to the WAF module to block IPs in the set
# This requires modifying the module to accept custom rules.
# For simplicity here, I will add the rule directly to the main WebACL definition in the module.
# In a real-world scenario, the module would be extended to take a list of custom rules.

# 3. IAM Role for the auto-block Lambda
resource "aws_iam_role" "waf_auto_block_lambda" {
  name = "${var.project_name}-waf-auto-block-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "waf_auto_block_lambda" {
  name   = "${var.project_name}-waf-auto-block-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["wafv2:GetIPSet", "wafv2:UpdateIPSet"],
        Effect   = "Allow",
        Resource = aws_wafv2_ip_set.auto_block_list.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "waf_auto_block_lambda" {
  role       = aws_iam_role.waf_auto_block_lambda.name
  policy_arn = aws_iam_policy.waf_auto_block_lambda.arn
}

# 4. CloudWatch Log Metric Filter, Alarm, and SNS Topic
# This part is complex as it depends on the WAF logs being enabled and having a predictable structure.
# The WAF logging for CloudFront must be sent to a Kinesis stream in us-east-1.
# This creates a cross-region dependency that is complex to manage in a single Terraform state.
# For this exercise, I will define the resources conceptually. A production implementation
# would likely use a separate Terraform stack/provider for the us-east-1 resources.

resource "aws_cloudwatch_log_metric_filter" "malicious_ips" {
  # This resource would need to be created in us-east-1
  provider = aws.east
  name           = "${var.project_name}-malicious-ip-filter"
  pattern        = "{ ($.action = \"BLOCK\") && ($.terminatingRuleId = \"JuiceShopSQLiBlock\") }"
  log_group_name = "/aws/waf/logs/${var.project_name}-waf" # Placeholder name

  metric_transformation {
    name      = "MaliciousIPCount"
    namespace = "WAFLogs"
    value     = "1"
    dimensions = {
      ClientIP = "$.httpRequest.clientIp"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "high_breach_attempts" {
  provider = aws.east
  alarm_name          = "${var.project_name}-high-breach-attempts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MaliciousIPCount"
  namespace           = "WAFLogs"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5" # e.g., 5 blocked requests from the same IP in 60 seconds
  alarm_description   = "This alarm triggers when a single IP is blocked multiple times."

  alarm_actions = [aws_sns_topic.waf_alarms.arn]
}

resource "aws_sns_topic" "waf_alarms" {
  provider = aws.east
  name = "${var.project_name}-waf-alarms"
}

# 5. The Lambda function for auto-blocking
data "archive_file" "waf_auto_block_lambda" {
  type        = "zip"
  source_dir  = "../lambda/waf-auto-block"
  output_path = "${path.module}/waf-auto-block-lambda.zip"
}

resource "aws_lambda_function" "waf_auto_block" {
  function_name = "${var.project_name}-waf-auto-block"
  handler       = "main.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.waf_auto_block_lambda.arn
  filename      = data.archive_file.waf_auto_block_lambda.output_path
  source_code_hash = data.archive_file.waf_auto_block_lambda.output_base64sha256

  environment {
    variables = {
      IP_SET_NAME  = aws_wafv2_ip_set.auto_block_list.name
      IP_SET_ID    = aws_wafv2_ip_set.auto_block_list.id
      IP_SET_SCOPE = "CLOUDFRONT"
    }
  }
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_auto_block.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.waf_alarms.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.waf_alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.waf_auto_block.arn
}

# --- WAF Logging Pipeline ---

# S3 Bucket for WAF Logs
resource "aws_s3_bucket" "waf_logs" {
  bucket = "${var.project_name}-waf-logs-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}


resource "aws_s3_bucket_policy" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  policy = data.aws_iam_policy_document.waf_logs_s3.json
}

data "aws_iam_policy_document" "waf_logs_s3" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.waf_logs.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "${var.project_name}-waf-logs-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.waf_logs.arn
    prefix     = "raw-logs/"
    error_output_prefix = "error-logs/"
    buffering_interval = 300
    buffering_size = 5
  }
}

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.project_name}-firehose-policy"
  role = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.waf_logs.arn,
          "${aws_s3_bucket.waf_logs.arn}/*"
        ]
      }
    ]
  })
}

# Security Group for the ECS Service
resource "aws_security_group" "ecs_service" {
  name        = "${var.project_name}-ecs-service-sg"
  description = "Allow traffic from ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
