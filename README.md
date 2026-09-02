# ICARUS

A deliberately over-permissioned AWS Bedrock agent lab for cloud-native
AI agent security research.

ICARUS is a customer-support agent built directly on **Amazon Bedrock's
Converse API**, with the tool-calling loop implemented in a single
**Lambda function** rather than a managed Bedrock Agent - real (if
intentionally misconfigured) AWS infrastructure behind it: IAM, S3, and
DynamoDB. Unlike [MARIONETTE](#) and [RAGnarok](#), which are
self-hosted labs for tool-calling and RAG attack research, ICARUS moves
the same class of problems onto an actual cloud AI platform - so the
vulnerabilities aren't just prompt-layer, they're prompt-layer bugs that
chain into real cloud-layer misconfiguration.

> **Why not a managed Bedrock Agent?** AWS closed Bedrock Agents
> Classic to new AWS accounts on July 30, 2026 - a fresh account can no
> longer call `CreateAgent`, with no exception process. Rather than
> route around it, this project adapted: Ada calls the Bedrock Converse
> API directly and handles the tool-calling loop herself. See
> `docs/attack-architecture.md` for the detail - the vulnerabilities
> and their mechanics are unchanged either way.

> **Ethical use:** deploy this only into an AWS account you own or are
> explicitly authorized to test in. Every "secret" and "internal" file in
> this repo is fake seed data generated for this lab - there is nothing
> real to protect and nothing real to steal. This exists for security
> research, training, and portfolio purposes.

## Documentation

| Doc | What's in it |
|---|---|
| [`docs/attack-architecture.md`](docs/attack-architecture.md) | What Ada can do, where the trust boundaries live, and how the three findings chain together - with diagrams |
| [`SETUP.md`](SETUP.md) | Deploying the lab into your own AWS account, step by step, including the Bedrock model-access gotchas |
| [`WALKTHROUGH.md`](WALKTHROUGH.md) | How to actually exercise each finding once it's deployed |
| [`docs/assessment-report-template.md`](docs/assessment-report-template.md) + [`docs/findings/`](docs/findings/) | Templates for writing up what you find |

## Vulnerability catalog

| # | Finding | Class | Maps to |
|---|---|---|---|
| 01 | Over-permissioned Lambda execution role lets the `fetch_document` tool read a bucket it was never meant to reach | Excessive Agency / insecure tool design | OWASP LLM06 (Excessive Agency), OWASP Agentic Top 10 (Tool Misuse), MITRE ATLAS AML.T0053 |
| 02 | Indirect prompt injection in a fetched "policy document" instructs the agent to pull from the internal bucket and exfiltrate the contents | Indirect Prompt Injection | OWASP LLM01 (Prompt Injection), MITRE ATLAS AML.T0051 |
| 03 | Verbose error handling leaks a plaintext API key from the Lambda's environment through the tool-result channel | Sensitive Information Disclosure | OWASP LLM02 (Sensitive Information Disclosure) |

Full detail on each, with a diagram of how 01 and 02 chain together, is
in `docs/attack-architecture.md`.

## Repo layout

```
icarus/
├── README.md
├── SETUP.md             Deployment guide
├── WALKTHROUGH.md        Attack exercise guide
├── terraform/            IaC for the whole stack (Lambda, IAM, S3, DynamoDB - no managed Bedrock Agent, see note above)
│   └── seed/              Seed documents planted in S3 (benign, injected, and "secret" variants)
├── lambda/               Ada - the vulnerable orchestrator + tool handler
├── agent/                Human-readable mirror of Ada's system prompt
└── docs/
    ├── attack-architecture.md          Trust boundaries and attack surface, with diagrams
    ├── assessment-report-template.md   Top-level report shell
    └── findings/                       One writeup per finding
```

## Cost

Everything here fits comfortably in AWS free-tier usage for a weekend of
testing. See `SETUP.md` for exact numbers and the teardown command.
