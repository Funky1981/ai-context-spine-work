---
description: Preserve context when forking a coding-session path or leaving unfinished Git branch work
---

Create a Context Spine branch/fork summary before leaving an unfinished line of work. The target or new branch/fork label is in $ARGUMENTS.

Use the active conversation/session as the primary evidence.

If this is also a Git branch switch:
1. Determine the current registered project slug and current Git branch.
2. Run ~/.agent-context/scripts/Get-BranchSummaryContext.ps1 -Project "<slug>" -ToBranch "<target-git-branch>".
3. Use the returned merge base, commits, changed files and recent session files as additional evidence.

If this is an OpenCode/session fork or simply an alternative approach rather than a Git branch:
1. Record the current session/fork identifier when available.
2. Use a clear human-readable from/to label for the path being left and the path being entered.
3. Preserve the decisions, experiments and unresolved work from the path being left.

Produce a concise structured summary using exactly these headings:
- ## Goal
- ## Constraints & Preferences
- ## Progress
  - ### Done
  - ### In Progress
  - ### Blocked
- ## Key Decisions
- ## Next Steps
- ## Critical Context

Preserve exact file paths, function/component names, errors, important evidence and materially read/modified files. Do not invent missing context.

Write the draft summary to a temporary local Markdown file, then persist it with Save-BranchSummary.ps1 using the from/to branch or fork labels. Delete only the temporary draft after the save succeeds.

Hard rule: branch/fork summarization is additive. Never delete or rewrite Git history, repository files, session history or raw Context Spine memory.
