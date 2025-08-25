variable "resource_arn" {
  description = "The ARN of the resource to associate the WAF with (ALB or CloudFront)."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "log_destination_arn" {
  description = "The ARN of the Kinesis Data Firehose delivery stream for WAF logs."
  type        = string
  default     = null
}

variable "scope" {
  description = "The scope of the WAF WebACL (REGIONAL or CLOUDFRONT)."
  type        = string
  default     = "REGIONAL"
}

variable "custom_rules" {
  description = "A list of custom rule statements to add to the WebACL."
  type        = any
  default     = []
}
