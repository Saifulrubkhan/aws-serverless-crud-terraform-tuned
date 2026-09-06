output "api_invoke_url" {
  description = "Base invoke URL for the API stage. See README.md > Deploy for the smoke test."
  value       = aws_api_gateway_stage.crud.invoke_url
}

output "lambda_function_name" {
  description = "Name of the deployed CRUD Lambda function, e.g. for the Power Tuning state machine input."
  value       = aws_lambda_function.crud_function.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed CRUD Lambda function, used as `lambdaARN` in the Power Tuning state machine input."
  value       = aws_lambda_function.crud_function.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table backing the API."
  value       = aws_dynamodb_table.items.name
}

output "power_tuning_state_machine_arn" {
  description = "ARN of the Lambda Power Tuning Step Functions state machine"
  value       = try(aws_serverlessapplicationrepository_cloudformation_stack.lambda_power_tuning.outputs["StateMachineARN"], "")
}

output "power_tuning_console_url" {
  description = "URL to view Power Tuning executions in AWS Console"
  value       = try(aws_serverlessapplicationrepository_cloudformation_stack.lambda_power_tuning.outputs["StateMachineARN"] != "" ? "https://console.aws.amazon.com/states/home?region=${var.aws_region}#/stateMachines/view/${aws_serverlessapplicationrepository_cloudformation_stack.lambda_power_tuning.outputs["StateMachineARN"]}" : "", "")
}
