# Trust policy - allows Lambda service to assume the role
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Permissions policy - grants DynamoDB and Logs access
data "aws_iam_policy_document" "lambda_custom_policy" {
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

# Create the IAM role with trust policy
resource "aws_iam_role" "lambda_custom_role" {
  name               = "lambda_custom_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Attach the permissions policy to the role
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name   = "lambda-apigateway-role"
  role   = aws_iam_role.lambda_custom_role.id
  policy = data.aws_iam_policy_document.lambda_custom_policy.json
}

# Inline Python code for Lambda function
locals {
  lambda_code = <<-EOT
import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def lambda_handler(event, context):
    http_method = event.get("httpMethod")
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")
    
    try:
        if http_method == "GET" and item_id is None:
            # List all items
            response = table.scan()
            return {
                "statusCode": 200,
                "body": json.dumps(response.get("Items", []))
            }
        
        elif http_method == "POST":
            # Create item
            body = json.loads(event.get("body", "{}"))
            body["id"] = body.get("id", str(datetime.now().timestamp()))
            table.put_item(Item=body)
            return {
                "statusCode": 201,
                "body": json.dumps(body)
            }
        
        elif http_method == "GET" and item_id:
            # Read item
            response = table.get_item(Key={"id": item_id})
            if "Item" in response:
                return {
                    "statusCode": 200,
                    "body": json.dumps(response["Item"])
                }
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "Item not found"})
            }
        
        elif http_method == "PUT" and item_id:
            # Update item
            body = json.loads(event.get("body", "{}"))
            body["id"] = item_id
            table.put_item(Item=body)
            return {
                "statusCode": 200,
                "body": json.dumps(body)
            }
        
        elif http_method == "DELETE" and item_id:
            # Delete item
            table.delete_item(Key={"id": item_id})
            return {
                "statusCode": 204,
                "body": ""
            }
        
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid request"})
        }
    
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
  EOT
}

# Archive the inline Python code for Lambda deployment
data "archive_file" "lambda_code" {
  type        = "zip"
  output_path = "${path.module}/../lambda_function.zip"

  source {
    content  = local.lambda_code
    filename = "handler.py"
  }
}

# Create Lambda function
resource "aws_lambda_function" "crud_function" {
  filename            = data.archive_file.lambda_code.output_path
  function_name       = "${local.name_prefix}-function"
  role                = aws_iam_role.lambda_custom_role.arn
  handler             = "handler.lambda_handler"
  runtime             = "python3.13"
  source_code_hash    = data.archive_file.lambda_code.output_base64sha256
  memory_size         = var.lambda_memory_size
  timeout             = var.lambda_timeout
  
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_custom_policy,
    aws_dynamodb_table.items
  ]
}