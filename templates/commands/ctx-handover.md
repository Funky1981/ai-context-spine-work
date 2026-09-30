---
description: Create a durable handover and run Context Spine maintenance
---

Create a new timestamped handover for the current registered project.

Store the raw handover as a new Markdown file beneath:

memory/projects/<project>/sessions/

Do not overwrite a previous session/handover file.

Capture:
- project and current objective
- completed work
- files/components materially changed
- tests/verification run and results
- important decisions and rationale
- unresolved risks/questions
- exact next action

Do not include secrets. Prefer repository references over copying large source blocks.

After saving the raw handover:
1. Run ~/.agent-context/scripts/Get-ContextMaintenance.ps1 -Project "<project>".
2. If compaction_required is true, execute the ctx-compact workflow automatically.
3. Never delete or rewrite the raw handover/session files after compaction.
