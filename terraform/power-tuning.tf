# AWS Lambda Power Tuning deployment
# This uses the SAM app to create a Step Functions state machine for tuning
# See README.md for usage instructions

resource "aws_serverlessapplicationrepository_cloudformation_stack" "lambda_power_tuning" {
  name           = "aws-lambda-power-tuning"
  application_id = "arn:aws:serverlessrepo:us-east-1:451282441545:applications/aws-lambda-power-tuning"
  capabilities   = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    PowerValues            = "128,256,512,1024,1536,3008"
    stateMachineNamePrefix = "${local.name_prefix}-power-tuning"
  }

  lifecycle {
    ignore_changes = [capabilities, parameters]
  }
}
