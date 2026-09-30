---
description: Compact older project session context without deleting the original history
---

Compact Context Spine history for the current registered project.

1. Determine the current project slug from the Context Spine project registry.
2. Run ~/.agent-context/scripts/Get-ContextMaintenance.ps1 -Project "<slug>".
3. If compaction_required is false, report that no compaction is required and stop.
4. If it is true, read only the source files listed in the generated plan plus any durable project memory needed to understand them.
5. Produce a concise structured summary using exactly these headings:
   - ## Goal
   - ## Constraints & Preferences
   - ## Progress
     - ### Done
     - ### In Progress
     - ### Blocked
   - ## Key Decisions
   - ## Next Steps
   - ## Critical Context
6. Preserve exact file paths, function/component names, error messages, decisions and unresolved work. Do not invent missing context.
7. Write the draft summary to a temporary local Markdown file.
8. Persist it with Save-Compaction.ps1 -Project "<slug>" -PlanPath "<plan>" -SummaryPath "<draft>".
9. Delete only the temporary draft after the save succeeds.

Hard rule: compaction is additive. Never delete, rewrite, truncate, move or replace the raw session/handover files that were summarized.
