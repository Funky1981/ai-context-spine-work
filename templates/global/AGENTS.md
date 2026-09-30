# AI Context Spine - global coding guidance

Use the current repository as the authoritative source for implementation truth.

## Context order

When useful for the task:
1. Read the project's own AGENTS.md and canonical documentation.
2. Use the registered project skill as an orientation map.
3. Search actual source files for implementation details.
4. Search Context Spine memory, compaction summaries and branch summaries for prior decisions/lessons.
5. Treat persistent memory as historical context, never as proof of current code state.
6. If generated context conflicts with the repository, the repository wins.

## Context lifecycle

- Raw session and handover files are historical evidence. Never delete, truncate or rewrite them during compaction.
- Compaction summaries are derived context and must remain traceable to the SHA-256 hashes of their raw sources.
- After creating a durable handover, run Get-ContextMaintenance.ps1 for the current project.
- If compaction is required, compact the planned older sessions while keeping recent context intact.
- Before leaving an unfinished Git branch, create a branch summary so abandoned or paused work remains discoverable.
- Imported legacy memory is additive. Never delete or modify the legacy source location during import.
- Use Search-Memory.ps1 for historical retrieval before loading large volumes of old session files.

## Safety

- Never store credentials, tokens, secrets or sensitive source excerpts in global memory.
- Never send repository content to an external provider unless the active profile explicitly permits it and the provider is approved for that environment.
- Work profile is GLM-only by default.
- Jev is optional and for narrow typed decisions only; it is not required for coding.
- Do not bypass security, proxy, endpoint, download or policy controls.

## Change discipline

- Inspect before editing.
- Keep changes scoped.
- Run the repository's relevant tests/verification.
- Call out uncertainty rather than inventing project facts.
- Rebuild local project index/skill after material structural changes.
