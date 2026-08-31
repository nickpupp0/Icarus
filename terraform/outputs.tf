output "agent_id" {
  value = aws_bedrockagent_agent.icarus.agent_id
}

output "agent_alias_id" {
  value = aws_bedrockagent_agent_alias.icarus_live.agent_alias_id
}

output "public_docs_bucket" {
  value = aws_s3_bucket.public_docs.id
}

output "internal_docs_bucket" {
  value = aws_s3_bucket.internal_docs.id
}

output "lambda_function_name" {
  value = aws_lambda_function.icarus_tools.function_name
}
