# Setup

Deploying ICARUS into your own AWS account, start to finish. Do these in
order - each step depends on the one before it.

## Prerequisites

- An AWS account you own or are explicitly authorized to deploy test
  infrastructure into.
- Terraform >= 1.5.
- The AWS CLI.

## 1. Create a deployment IAM user

Log into the AWS Console. Go to **IAM > Users > Create user**, name it
something like `icarus-deploy`. For a personal lab account like this,
attach `AdministratorAccess` to avoid chasing missing permissions
mid-deploy - tighten it later if you want (`IAMFullAccess`,
`AmazonS3FullAccess`, `AmazonDynamoDBFullAccess`, `AWSLambda_FullAccess`,
and `AmazonBedrockFullAccess` covers everything Terraform needs here).

Then, on that user's **Security credentials** tab, go to **Access keys >
Create access key > Command Line Interface (CLI)** use case. Save the
Access Key ID and Secret Access Key immediately - the secret is shown
only once.

## 2. Install and configure the AWS CLI

Install it (`sudo apt install awscli` on Kali/Debian, or grab the
official v2 installer). Then:

```bash
aws configure
```

Paste in the Access Key ID, Secret Access Key, set the default region to
`us-east-1` (matches `terraform/variables.tf`), and output format
`json`. Verify:

```bash
aws sts get-caller-identity
```

This should print your account ID and the `icarus-deploy` user's ARN.

## 3. Enable Bedrock model access

In the AWS Console, go to **Bedrock > Model access** and request access
to Anthropic Claude 3 Haiku, in the same region you configured above.

**If you hit a "use case" form and don't have a company:** this is a
real, one-time requirement from Anthropic as the model provider (not
something AWS or this lab can route around), and AWS's own docs address
it directly - for individuals without a company site, use a personal or
GitHub profile URL instead. Suggested field values:

| Field | Value |
|---|---|
| Company name | Your name, or "Independent Security Research" |
| Company website | Your GitHub profile URL |
| Industry | Technology |
| Intended users | Internal / yourself |
| Use case | "Independent security research project - building and testing a deliberately vulnerable AI agent (Bedrock model invocation + Lambda tool-calling) for AI/LLM red-teaming skills development and a public portfolio piece. No production systems or customer data involved." |

Access is normally granted immediately after submission - this is an
acknowledgment form, not a review queue.

**Fallback with zero extra steps:** if you'd rather skip this
entirely, Amazon's own Nova models (`amazon.nova-micro-v1:0`,
`amazon.nova-lite-v1:0`) require no use-case form at all. Change
`foundation_model` in `terraform/variables.tf` to one of those and
you're unblocked immediately - none of the three findings depend on
which model is answering, since the vulnerabilities all live in the
IAM/tool-calling/injection layer, not the model itself.

## 4. Install Terraform

On Kali/Debian, add HashiCorp's apt repo and `sudo apt install
terraform`, or grab a binary from `releases.hashicorp.com/terraform`.
Confirm with `terraform version` (need >= 1.5).

## 5. Double-check variables.tf

Open `terraform/variables.tf`. Confirm `aws_region` matches where you
enabled model access, and `foundation_model` exactly matches the model
ID shown as "Access granted" in the Bedrock console - model IDs
sometimes carry version suffixes, so copy the exact string from the
console rather than trusting the file's default.

## 6. Deploy

From the `terraform/` directory:

**Don't prefix any of these with `sudo`.** Your AWS credentials from step
2 live in `~/.aws/credentials` under your normal user - running as root
via `sudo` looks in `/root/.aws/credentials` instead, finds nothing,
falls back to trying EC2 instance metadata, and fails with "No valid
credential sources found." Terraform doesn't need root - it's only
making HTTPS calls and writing files in the current directory. If you
extracted this project somewhere like `/opt/` and hit a permissions
error without `sudo`, fix the directory ownership once instead:
`sudo chown -R $(whoami):$(whoami) /path/to/icarus`. If you've already
run a `plan` or `apply` with `sudo` before catching this, run that same
`chown` command again afterward too - it'll also fix ownership on
anything `sudo` already created (most commonly `terraform/build/`,
which will otherwise block a later non-`sudo` run with a "permission
denied" error on that specific directory).

```bash
terraform init
```

Downloads the provider plugins. No AWS calls yet.

```bash
terraform plan
```

**This is a dry run - it does not create, modify, or touch any AWS
resources**, and is safe to run as many times as you want. It just
prints exactly what `apply` would create. Read through the ~17
resources it lists - all mature, well-established resource types
(IAM, S3, DynamoDB, Lambda, CloudWatch Logs), so a clean `plan` here
is a good sign.

```bash
terraform apply
```

Type `yes` to confirm. This is the actual deploy.

## 7. Verify

Note the `lambda_function_name` output (should be `icarus-agent-tools`).
Ada isn't a managed Bedrock Agent with a console Test panel - she's a
Lambda you invoke directly:

```bash
aws lambda invoke --function-name icarus-agent-tools \
  --cli-binary-format raw-in-base64-out \
  --payload '{"message": "What is the status of order ORD-1001?"}' \
  response.json

cat response.json
```

A normal response with an order status confirms the Lambda, its IAM
role, Bedrock model access, and DynamoDB are all correctly wired
together. The JSON response includes a `trace` field showing every tool
call Ada made along the way - that's your evidence trail for
`WALKTHROUGH.md`.

You're now ready for `WALKTHROUGH.md`.

## Teardown

```bash
terraform destroy
```

Tears down everything Terraform created - the Lambda function and its
CloudWatch log group, both IAM roles and policies, both S3 buckets
(including any test objects left in them, via `force_destroy`), and the
DynamoDB table. Terraform destroys in reverse dependency order
automatically.

To confirm nothing was left running, check the console for these four
resource types in your region - Lambda functions, S3 buckets, DynamoDB
tables, CloudWatch log groups - and search each for "icarus." The only
thing `destroy` can't remove is the one-time Anthropic model-access
grant on your account, which is account-level, not a deployed resource,
and costs nothing to leave in place.

## Cost

Everything here fits comfortably in AWS free-tier usage for a weekend of
testing - a handful of Lambda invocations, a few KB of S3 storage,
minimal DynamoDB reads. Bedrock model invocations are billed per-token
but at Haiku (or Nova Micro) pricing this is pennies for a testing
session. Run `terraform destroy` when you're done to avoid any ongoing
charges.
