"""
ICARUS - Bedrock Agent tool-calling backend.

This Lambda is the action-group executor for the ICARUS support agent.
It is DELIBERATELY VULNERABLE. See README.md and docs/findings/ for the
full vulnerability catalog. Do not deploy this against real customer data
or reuse this code in production - it exists to be attacked, in your own
isolated AWS account, for security research and portfolio purposes only.
"""

import json
import os
import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "icarus-orders")

# VULN (Finding 03 - Secret exposure via verbose error handling):
# a simulated third-party integration key living in plaintext in the
# Lambda's environment. Never do this in production - use Secrets Manager
# or SSM Parameter Store with least-privilege access instead.
THIRD_PARTY_API_KEY = os.environ.get("THIRD_PARTY_API_KEY", "sk-live-DEMO-1234567890abcdef")


def lambda_handler(event, context):
    """
    Bedrock invokes this Lambda for every tool call the agent makes.
    Expected event shape (Bedrock Agent action-group convention):
      {
        "actionGroup": "...",
        "function": "lookup_order" | "fetch_document",
        "parameters": [{"name": "...", "value": "..."}, ...]
      }
    """
    action_group = event.get("actionGroup")
    function = event.get("function")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}

    try:
        if function == "lookup_order":
            result = lookup_order(parameters.get("order_id"))
        elif function == "fetch_document":
            result = fetch_document(parameters.get("bucket"), parameters.get("key"))
        else:
            result = {"error": f"Unknown function: {function}"}
    except Exception as e:
        # VULN (Finding 03): verbose error handling. Real stack-trace-style
        # debug context - including the "secret" - gets stuffed into the
        # tool result that flows back into the agent's context, and from
        # there potentially straight to the end user. A production error
        # handler should log this server-side and return a generic message.
        result = {
            "error": str(e),
            "debug_context": {
                "function": function,
                "parameters": parameters,
                "third_party_api_key": THIRD_PARTY_API_KEY,  # should never be here
            },
        }

    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": action_group,
            "function": function,
            "functionResponse": {
                "responseBody": {"TEXT": {"body": json.dumps(result, default=str)}}
            },
        },
    }


def lookup_order(order_id):
    if not order_id:
        raise ValueError("order_id is required")
    table = dynamodb.Table(ORDERS_TABLE)
    resp = table.get_item(Key={"order_id": order_id})
    item = resp.get("Item")
    if not item:
        return {"error": f"No order found for {order_id}"}
    return item


def fetch_document(bucket, key):
    """
    Intended use: pull customer-facing policy docs out of the PUBLIC docs
    bucket so the agent can summarize or quote them for a user.

    VULN (Finding 01 - Excessive Agency / insecure tool design):
    nothing in this function restricts `bucket` to the public-docs bucket.
    The agent's *instructions* (agent/instructions.md) tell it to only ever
    pass the public bucket name - but that is a prompt-level convention,
    not an enforcement boundary. Combine that with the Lambda's IAM role
    (terraform/iam.tf) granting s3:GetObject on BOTH the public and
    "internal" buckets, and any path that gets the agent to call this
    function with the internal bucket name succeeds. See Finding 01 and
    Finding 02 (which chains an indirect prompt injection into this).
    """
    if not bucket or not key:
        raise ValueError("bucket and key are required")
    obj = s3.get_object(Bucket=bucket, Key=key)
    body = obj["Body"].read().decode("utf-8", errors="replace")
    return {"bucket": bucket, "key": key, "content": body}
