# Work Setup

The work profile assumes:
- Windows/PowerShell
- OpenCode already configured with the employer-approved GLM provider
- no external AI provider is required
- GitHub may be readable in the browser even when cloning/downloading is restricted

## Copy/paste installation

1. Open bootstrap.ps1 on GitHub.
2. Copy the whole file.
3. Create a local bootstrap.ps1.
4. Review it.
5. Run:

    .\bootstrap.ps1 -Profile work -InstallOpenCode

If a global OpenCode AGENTS.md already exists, the bootstrap will not overwrite it. It creates OPENCODE_SNIPPET.md under the context root so you can review and merge the small integration block manually.

## Existing memory is migrated automatically

The installer automatically detects the previous global OpenCode location:

    ~/.config/opencode/

That matches the earlier work layout containing:

    memory/MEMORY.md
    memory/lessons.md
    memory/preferences.md
    memory/projects/
    commands/

The migration is non-destructive:

- the old files remain exactly where they are;
- a raw snapshot is copied under ~/.agent-context/imports/;
- an audit manifest is written under ~/.agent-context/migrations/;
- global memory is appended with SHA-256 import markers rather than replaced;
- project memory is copied into ~/.agent-context/memory/projects/;
- any conflicting project-memory file is preserved under a hash-suffixed imported filename rather than overwritten.

For another context folder, add:

    -ImportContextPath "C:\path\to\old\context"

Run Test-Workspace.ps1 after installation and inspect the migration manifests if you want to verify exactly what was imported.

## Compaction and branch summaries

Compaction is local-first and additive. Raw session/handover files are preserved. The active OpenCode/GLM agent creates summaries only when the deterministic maintenance check says older session context exceeds the configured soft threshold.

No second model is required.

Before leaving unfinished branch work, use the branch-summary command so the paused branch remains understandable without reloading the entire old conversation.

See CONTEXT-LIFECYCLE.md for the full lifecycle contract.

## Register internal projects

Example:

    ~/.agent-context/scripts/Register-Project.ps1 -Name "SQL Patching" -Path "C:\path\to\repo"

All generated project records, hashes, memory and skills stay local.

## Jev at work

The checked-in work profile blocks Jev. Do not enable it unless your employer explicitly approves TypeSafe/Jev as an external processor. If approval happens later, the adapter is already present and can be enabled with Enable-Jev.ps1 -ApprovedForWork.

Nothing in this repository attempts to evade email, download, endpoint, proxy or security controls.
