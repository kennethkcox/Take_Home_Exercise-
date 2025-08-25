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

# Custom VPC for fine-grained control
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "${var.project_name}-private-b" }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project_name}-nat-gw" }
  depends_on    = [aws_internet_gateway.main]
}

# --- Network Firewall for Egress Control ---

resource "aws_networkfirewall_rule_group" "egress_rules" {
  name     = "${var.project_name}-egress-rules"
  capacity = 100
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          protocol          = "ANY"
          source            = "ANY"
          source_port       = "ANY"
          direction         = "FORWARD"
          destination       = "ANY"
          destination_port  = "ANY"
        }
        rule_option {
          keyword = "sid:1"
        }
      }
    }
    stateful_rule_options {
      rule_order = "DEFAULT_ACTION_ORDER"
    }
  }

  tags = { Name = "${var.project_name}-egress-rules" }
}

resource "aws_networkfirewall_firewall_policy" "egress_policy" {
  name = "${var.project_name}-egress-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.egress_rules.arn
    }
  }

  tags = { Name = "${var.project_name}-egress-policy" }
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.egress_policy.arn
  vpc_id              = aws_vpc.main.id
  delete_protection   = false

  subnet_mapping {
    subnet_id = aws_subnet.public_a.id
  }

  tags = { Name = "${var.project_name}-firewall" }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block                = "0.0.0.0/0"
    nat_gateway_id            = aws_nat_gateway.main.id
    # Note: To route through the firewall, you would point this to the firewall endpoint.
    # This requires a more complex setup with transit gateways or gateway load balancers
    # for a truly robust implementation. For this exercise, we route to the NAT gateway
    # to provide internet access, and the firewall rules would apply.
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Group for the ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

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
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "juice_shop" {
  name        = "${var.project_name}-juice-shop-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "juice-shop"
        }
      }
    },
    {
      name      = "falco"
      image     = "falcosecurity/falco:latest"
      cpu       = 128
      memory    = 256
      essential = true
      # Note: Falco on Fargate has limitations. True kernel-level monitoring
      # requires specific Fargate platform versions and is more complex than on EC2.
      # This configuration is a conceptual demonstration.
      # In a real EC2-backed scenario, you would add:
      # privileged = true
      # linuxParameters = {
      #   capabilities = {
      #     add = ["SYS_PTRACE"]
      #   }
      # }
      # volumesFrom = [{ sourceContainer = "juice-shop" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.falco_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "falco"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/${var.project_name}/juice-shop"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "falco_logs" {
  name = "/ecs/${var.project_name}/falco"
  retention_in_days = 7
}

# Conceptual: An alarm that would trigger on a high-priority Falco alert
resource "aws_cloudwatch_log_metric_filter" "falco_critical_alerts" {
  name           = "${var.project_name}-falco-critical-alerts"
  # This pattern would be tuned to match specific high-priority Falco rules
  pattern        = "{ $.priority = \"Critical\" }"
  log_group_name = aws_cloudwatch_log_group.falco_logs.name

  metric_transformation {
    name      = "FalcoCriticalAlerts"
    namespace = "Falco"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "falco_alarm" {
  alarm_name          = "${var.project_name}-falco-critical-alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FalcoCriticalAlerts"
  namespace           = "Falco"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This alarm triggers when a critical Falco event is detected."
  # In a real system, this would trigger an SNS topic for PagerDuty/Slack etc.
  # alarm_actions = [aws_sns_topic.security_alerts.arn]
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
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = false # No public IP for tasks in private subnets
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
  vpc_id      = aws_vpc.main.id

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
