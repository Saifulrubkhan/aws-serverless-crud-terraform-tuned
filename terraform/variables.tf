variable "project_name" {
  description = "Short name used to prefix all resources (e.g. dynamodb table, lambda function, API)."
  type        = string
  default     = "crud-api"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "lambda_memory_size" {
  description = "Lambda memory in MB. See README.md > Power tuning for how this was chosen."
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. Default retention is \"never expire\", which quietly becomes the largest line item — see README.md > Cost analysis."
  type        = number
  default     = 14
}

variable "dynamodb_billing_mode" {
  description = "PAY_PER_REQUEST (on-demand) or PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "api_stage_name" {
  description = "API Gateway deployment stage name."
  type        = string
  default     = "v1"
}
