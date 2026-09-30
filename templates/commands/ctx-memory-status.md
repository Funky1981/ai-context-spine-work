---
description: Summarize relevant local memory, lifecycle state and stale or conflicting items
---

Review the local AI Context Spine memory relevant to the current project.

Use Search-Memory.ps1 for historical retrieval and Test-Staleness.ps1 for repository index state.

Also run Get-ContextMaintenance.ps1 for the current project and report whether compaction is currently required.

Report:
- durable project decisions
- useful lessons
- unresolved handovers
- recent compaction summaries
- relevant branch summaries
- compaction-required status
- anything that appears stale or conflicts with current repository truth
- legacy import manifests when migration provenance matters

Repository source and committed project instructions override memory. Raw imported/session history must remain preserved.
