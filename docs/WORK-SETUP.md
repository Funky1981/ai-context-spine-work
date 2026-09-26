# Work Setup

The work profile assumes:
- Windows/PowerShell
- OpenCode already configured with the employer-approved GLM provider
- no external AI provider is required
- GitHub may be readable in the browser even when cloning/downloading is restricted

## Copy/paste installation

1. Open `bootstrap.ps1` on GitHub.
2. Copy the whole file.
3. Create a local `bootstrap.ps1`.
4. Review it.
5. Run:

```powershell
.\bootstrap.ps1 -Profile work -InstallOpenCode
```

If a global OpenCode `AGENTS.md` already exists, the bootstrap will not overwrite it. It creates `OPENCODE_SNIPPET.md` under the context root so you can review and merge the small integration block manually.

## Existing memory

If you already have `MEMORY.md`, `lessons.md`, `preferences.md` and project memory files, do not overwrite them. Either point the new workspace at the existing files or copy their contents into the generated memory folder after review.

## Register internal projects

Example:

```powershell
~/.agent-context/scripts/Register-Project.ps1 -Name "SQL Patching" -Path "C:\path\to\repo"
```

All generated project records, hashes and skills stay local.

## Jev at work

The checked-in work profile blocks Jev. Do not enable it unless your employer explicitly approves TypeSafe/Jev as an external processor. If approval happens later, the adapter is already present and can be enabled with `Enable-Jev.ps1 -ApprovedForWork`.

Nothing in this repository attempts to evade email, download, endpoint, proxy or security controls.
