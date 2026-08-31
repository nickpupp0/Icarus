# -----------------------------------------------------------------------
# NOTE ON THIS FILE: Bedrock Agent resources are one of the newest parts
# of the hashicorp/aws provider and the schema has shifted between
# provider versions. This was written from documented resource shapes but
# has NOT been apply-tested (this environment has no AWS network access).
# Treat it as a strong, structurally-correct starting point - run
# `terraform plan`, diff any errors against the current aws_bedrockagent_*
# docs on the Terraform Registry, and adjust field names as needed before
# `apply`. The IAM, S3, DynamoDB, and Lambda resources in the other files
# are mature, stable resources and should apply cleanly as-is.
# -----------------------------------------------------------------------

resource "aws_bedrockagent_agent" "icarus" {
  agent_name                  = "icarus-support-agent"
  agent_resource_role_arn     = aws_iam_role.icarus_agent_role.arn
  foundation_model            = var.foundation_model
  instruction                 = file("${path.module}/../agent/instructions.md")
  idle_session_ttl_in_seconds = 600
}

resource "aws_bedrockagent_agent_action_group" "icarus_tools" {
  agent_id          = aws_bedrockagent_agent.icarus.agent_id
  agent_version     = "DRAFT"
  action_group_name = "icarus-tools"

  action_group_executor {
    lambda = aws_lambda_function.icarus_tools.arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "lookup_order"
        description = "Look up the status of a customer's order by order ID"

        parameters {
          map_block_key = "order_id"
          type          = "string"
          required      = true
          description   = "The order ID to look up, e.g. ORD-1001"
        }
      }

      functions {
        name        = "fetch_document"
        description = "Fetch a customer-facing policy document to summarize or quote"

        parameters {
          map_block_key = "bucket"
          type          = "string"
          required      = true
          description   = "S3 bucket name containing the document"
        }
        parameters {
          map_block_key = "key"
          type          = "string"
          required      = true
          description   = "S3 object key of the document"
        }
      }
    }
  }
}

resource "aws_bedrockagent_agent_alias" "icarus_live" {
  agent_id         = aws_bedrockagent_agent.icarus.agent_id
  agent_alias_name = "live"

  depends_on = [aws_bedrockagent_agent_action_group.icarus_tools]
}
