# Optional Jev Adapter

Jev is an optional external decision-engine adapter.

It is intended for narrow typed questions such as:
- is this file/diff relevant to a task?
- did an API contract change?
- which category best fits this failure?
- should a result be escalated for deeper review?

It is not the coding model and does not replace GLM, Codex or another engineering agent.

## API contract used

The adapter uses TypeSafe's current System One endpoint:

```text
POST https://api.typesafe.ai/v1/systemone
Authorization: Bearer $JEV_API_KEY
```

The included V1 wrapper sends a `noul` (yes/no probability) question using model alias `jev-latest`.

## Enable at home

```powershell
$env:JEV_API_KEY = "..."
~/.agent-context/scripts/Enable-Jev.ps1
```

## Work

Work is blocked by default. `Enable-Jev.ps1` refuses a work profile unless `-ApprovedForWork` is supplied. That flag is an acknowledgement that policy approval already exists; it is not approval itself.

## Secrets

The key is read from `JEV_API_KEY`. It is never written to `config.json`.

## Provider independence

Future adapters should implement the same conceptual operations:
- Yes/No
- Choice
- Score

Core indexing, memory and skills must never depend on Jev.
