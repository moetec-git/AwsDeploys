
variable "aws_region" {
  type        = string
  description = "aws region used for resources"
  default     = "us-east-2"
}

variable "billing_code" {
  type        = string
  description = "Billing code for resource tagging"
}



