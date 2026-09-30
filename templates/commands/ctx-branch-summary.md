---
description: Preserve the work being left behind when moving to another Git branch
---

Create a Context Spine branch summary before leaving the current branch. The target branch is in $ARGUMENTS.

1. Determine the current registered project slug and current Git branch.
2. Run ~/.agent-context/scripts/Get-BranchSummaryContext.ps1 -Project "<slug>" -ToBranch "<target>".
3. Read the returned changed-file list, commits, recent session files and only the repository files needed to understand the paused work.
4. Produce a concise structured summary using exactly these headings:
   - ## Goal
   - ## Constraints & Preferences
   - ## Progress
     - ### Done
     - ### In Progress
     - ### Blocked
   - ## Key Decisions
   - ## Next Steps
   - ## Critical Context
5. Explicitly record the from-branch, to-branch, common ancestor and materially read/modified files.
6. Write the draft summary to a temporary local Markdown file.
7. Persist it with Save-BranchSummary.ps1.
8. Delete only the temporary draft after the save succeeds.
9. Continue with the branch switch only if the user already requested it.

Hard rule: never delete or rewrite Git history, source files or raw Context Spine session memory as part of branch summarization.
