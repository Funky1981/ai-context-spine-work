# Home Setup

Run:

    .\bootstrap.ps1 -Profile home -InstallOpenCode

If ~/.config/opencode/ already contains your older memory, the installer imports it automatically without deleting or overwriting the source files.

For an additional legacy context folder:

    .\bootstrap.ps1 -Profile home -InstallOpenCode -ImportContextPath "C:\AI-Memory"

Then register repositories:

    ~/.agent-context/scripts/Register-Project.ps1 -Name "Jax" -Path "C:\Projects\Jax\jax-trading-assistant"
    ~/.agent-context/scripts/Register-Project.ps1 -Name "OSINT" -Path "C:\Projects\osint-security-platform"

Historical memory search:

    ~/.agent-context/scripts/Search-Memory.ps1 -Project "jax" -Pattern "structured outputs"

Compaction and branch summaries use the currently active coding agent. Raw history is preserved; summaries are additive.

The system works without Jev.

If you later want Jev:

    $env:JEV_API_KEY = "your-key-from-a-secret-store"
    ~/.agent-context/scripts/Enable-Jev.ps1

Test the adapter with non-sensitive content before routing any real workflow through it.
