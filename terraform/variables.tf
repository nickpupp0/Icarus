variable "aws_region" {
  description = "AWS region to deploy ICARUS into. Must be a region with Bedrock model access enabled for your account."
  type        = string
  default     = "us-east-1"
}

variable "foundation_model" {
  description = "Bedrock foundation model ID for the agent. Must be enabled for your account in the console under Bedrock > Model access."
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}
