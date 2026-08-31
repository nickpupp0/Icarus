# -----------------------------------------------------------------------
# Lambda execution role
# -----------------------------------------------------------------------

resource "aws_iam_role" "icarus_lambda_role" {
  name = "icarus-agent-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.icarus_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ***** FINDING 01 - EXCESSIVE AGENCY / OVER-PERMISSIONED EXECUTION ROLE *****
# The fetch_document tool only ever NEEDS s3:GetObject on the public-docs
# bucket, and lookup_order only needs dynamodb:GetItem on the orders table.
# Instead, this policy grants read access to the internal bucket too - the
# one the tool was never supposed to reach. This is the single change that
# turns "insecure tool design" into "actual data exposure": the fetch_document
# function itself does no bucket allow-listing (see lambda/handler.py), so
# the IAM boundary was the only thing that could have stopped this, and it
# doesn't.
resource "aws_iam_role_policy" "icarus_lambda_permissions" {
  name = "icarus-overpermissioned-s3-policy"
  role = aws_iam_role.icarus_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OverPermissionedS3Read"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.public_docs.arn,
          "${aws_s3_bucket.public_docs.arn}/*",
          aws_s3_bucket.internal_docs.arn,        # <- should not be granted
          "${aws_s3_bucket.internal_docs.arn}/*", # <- should not be granted
        ]
      },
      {
        Sid      = "OrdersTableAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = aws_dynamodb_table.orders.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------
# Bedrock agent resource role (lets the agent invoke the foundation model
# and the action-group Lambda). This one is scoped correctly - the bug
# lives in the Lambda's role above, not here. Worth calling out in your
# report as a contrast: least-privilege was applied inconsistently, not
# uniformly missing.
# -----------------------------------------------------------------------

resource "aws_iam_role" "icarus_agent_role" {
  name = "icarus-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "icarus_agent_invoke_model" {
  name = "icarus-agent-invoke-model"
  role = aws_iam_role.icarus_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeFoundationModel"
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.foundation_model}"
    }]
  })
}
