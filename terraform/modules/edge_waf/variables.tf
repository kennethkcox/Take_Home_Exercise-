variable "alb_arn" {
  description = "The ARN of the Application Load Balancer to associate the WAF with."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "log_destination_arn" {
  description = "The ARN of the Kinesis Data Firehose delivery stream for WAF logs."
  type        = string
}
