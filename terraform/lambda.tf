# Managing this explicitly means `terraform destroy` removes it too - left
# unmanaged, Lambda auto-creates this log group on first invocation and it
# would otherwise survive teardown as an orphaned (low-cost, but pointless)
# resource.
resource "aws_cloudwatch_log_group" "icarus_lambda_logs" {
  name              = "/aws/lambda/icarus-agent-tools"
  retention_in_days = 7
}

data "archive_file" "icarus_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/build/icarus-lambda.zip"
}

resource "aws_lambda_function" "icarus_tools" {
  function_name    = "icarus-agent-tools"
  role             = aws_iam_role.icarus_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.icarus_lambda_zip.output_path
  source_code_hash = data.archive_file.icarus_lambda_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ORDERS_TABLE = aws_dynamodb_table.orders.name
      # ***** FINDING 03 seed value ***** - a "real" secret sitting in
      # plaintext in the Lambda's environment, simulating a third-party
      # integration key. It only becomes reachable through the verbose
      # error-handling bug in handler.py, not directly - that's the point.
      THIRD_PARTY_API_KEY = "sk-live-DEMO-1234567890abcdef"
    }
  }
}

resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.icarus_tools.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.icarus.agent_arn
}
