resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  # Rule for AWS Managed Rule Set - Common
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsCommonRules"
      sampled_requests_enabled   = true
    }
  }

  # Rule for AWS Managed Rule Set - SQLi
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsSQLiRules"
      sampled_requests_enabled   = true
    }
  }

  # Custom Rule for Juice Shop SQLi
  rule {
    name     = "JuiceShopSQLiBlock"
    priority = 1
    action {
      block {}
    }
    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string = "/rest/products/search"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "EXACTLY"
          }
        }
        statement {
          byte_match_statement {
            search_string = "' OR 1=1--"
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "juiceShopSQLiBlock"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-metrics"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [var.log_destination_arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}
