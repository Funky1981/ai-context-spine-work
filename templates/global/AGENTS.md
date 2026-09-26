# AI Context Spine - global coding guidance

Use the current repository as the authoritative source for implementation truth.

## Context order

When useful for the task:
1. Read the project's own AGENTS.md and canonical documentation.
2. Use the registered project skill as an orientation map.
3. Search actual source files for implementation details.
4. Use persistent memory for prior decisions/lessons, never as proof of current code state.
5. If generated context conflicts with the repository, the repository wins.

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
