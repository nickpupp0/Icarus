# Finding 03: Secret Disclosure via Verbose Error Handling

**Severity:** _fill in (suggest: Medium-High depending on how directly the user-facing reply surfaces the key)_
**OWASP mapping:** LLM02 - Sensitive Information Disclosure

## Description

`lambda/handler.py`'s exception handler includes a `debug_context` block
in its error response, containing the function name, the parameters that
were passed, and the value of `THIRD_PARTY_API_KEY` pulled from the
Lambda's environment. This is a common real-world pattern: verbose error
handling left enabled from development, intended to help debugging, that
ends up shipping to production. In an agentic system specifically, this
is worse than in a traditional API, because the error payload doesn't
stop at a log file - it flows back into the agent's context as a tool
result, and from there the model may include some or all of it in its
reply to the end user.

## Impact

Any input that reliably triggers an exception in `fetch_document` or
`lookup_order` (e.g., a malformed or missing parameter) surfaces the
plaintext API key. Depending on how the model handles the error content,
this may require no adversarial technique at all beyond a malformed
request - it isn't gated behind prompt injection or IAM bypass the way
Findings 01 and 02 are.

## Reproduction steps

_Fill in once tested._

1. Trigger an error condition - e.g., ask Ada to look up an order with a
   missing or clearly invalid order ID, or fetch a document with a
   malformed bucket/key.
2. Inspect the tool result in the Bedrock trace for the `debug_context`
   block and the API key value.
3. Separately, note whether the key value made it into Ada's actual reply
   to the user, or stayed contained in the trace/tool-result layer only -
   both are worth recording, since they represent different real-world
   severities (internal trace visibility vs. direct user exposure).

## Evidence

_Trace excerpt showing the leaked value._

## Remediation

1. Never include raw exception details or environment values in a tool's
   response body. Log the full error server-side (CloudWatch already
   captures this via the Lambda's basic execution role) and return a
   generic, non-parameterized error message to the caller.
2. Move `THIRD_PARTY_API_KEY` out of a plaintext environment variable and
   into Secrets Manager or SSM Parameter Store, retrieved only at the
   point of use, never held in a variable that a broad exception handler
   could serialize.
3. Add a schema/shape check on tool responses before they're returned to
   Bedrock, as a backstop against future code changes reintroducing this
   pattern.
