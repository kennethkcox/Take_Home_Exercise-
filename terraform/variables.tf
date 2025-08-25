variable "aws_region" {
  description = "The AWS region to deploy the resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "adobe-sec-challenge"
}

variable "juice_shop_image" {
  description = "The Docker image for OWASP Juice Shop."
  type        = string
  default     = "bkimminich/juice-shop"
}
