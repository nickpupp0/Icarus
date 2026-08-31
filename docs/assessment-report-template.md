# ICARUS - AI Agent Security Assessment

**Target:** ICARUS support agent (Amazon Bedrock Agents + Lambda action group)
**Assessment type:** Combined black-box (agent interaction) and white-box (IaC + source review)
**Assessor:**
**Date:**
**Scope:** Bedrock agent, its action-group Lambda, associated IAM roles, S3 buckets, DynamoDB table

## 1. Executive summary

_2-3 sentences, non-technical: what was tested, what was found, overall
risk. Write this last, once you know what you're summarizing._

## 2. Methodology

- White-box review of `terraform/` (IAM policies, resource configuration)
  and `lambda/handler.py` (tool implementation logic)
- Black-box testing of the deployed agent via the Bedrock console test
  window / `bedrock-agent-runtime` API, treating it as an authenticated
  end user would experience it
- Findings mapped to OWASP Top 10 for LLM Applications, OWASP Top 10 for
  Agentic Applications, and MITRE ATLAS where applicable

## 3. Findings summary

| ID | Finding | Severity | Status |
|---|---|---|---|
| 01 | Excessive agency via over-permissioned Lambda role | | |
| 02 | Indirect prompt injection chains into Finding 01 | | |
| 03 | Secret disclosure via verbose error handling | | |

_Fill in severity (Critical/High/Medium/Low) using whatever framework you
want to demonstrate here - CVSS 3.1 environmental score, or a simpler
Likelihood x Impact rubric, both are defensible for an LLM-app finding
and it's worth explicitly justifying your choice in this report, since
CVSS doesn't map cleanly onto agentic-AI findings and reviewers will
notice if you handle that thoughtfully vs. blindly._

## 4. Detailed findings

See `docs/findings/01-*.md`, `02-*.md`, `03-*.md` for full writeups.
Each should include: description, impact, reproduction steps (with
actual request/response pairs from your testing), root cause, and
remediation.

## 5. Architecture observations

_What did the white-box review surface beyond the three seeded findings?
E.g.: was least-privilege applied inconsistently between the Lambda role
and the agent's own resource role? Is there any logging/monitoring that
would have caught this in a real deployment? This section is where you
demonstrate judgment beyond "found the bugs that were planted" - genuinely
useful for the parts of the JD about reviewing architecture and
contributing to methodology, not just running a checklist._

## 6. Remediation recommendations

_Prioritized list. For each of the three findings, what's the fix -
scope the IAM policy, add allow-listing in the tool code itself (don't
rely on the model to self-enforce), sanitize/isolate fetched external
content before it enters the agent's context, move secrets to Secrets
Manager and return generic errors._
