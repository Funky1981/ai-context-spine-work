# Incident Investigator Prompts

This folder is deliberately separate from the other work in this repository.

## Current direction

The Incident Investigator POC is pivoting to an **alerting-first** milestone:

**Splunk ERROR/FATAL events → deterministic grouping → incidents → linked-event counts/evidence → dashboard + alerts.**

The existing causal/root-cause work is preserved, but root-cause ranking is not a V1 requirement because current evaluation shows that layer still needs improvement.

## Files

- `01-alerting-first-pivot.md` — use this first. It tells the coding agent to review the existing repository, preserve the current evidence, redesign the remaining roadmap around alerting/triage, and stop before implementation.

## Important

This GitHub repository is public. These prompts are intentionally written without internal hostnames, credentials, tokens, proprietary Splunk queries, internal repository contents, or confidential implementation details.

Do not add such information to this repository.
