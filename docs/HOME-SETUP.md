# Home Setup

Run:

```powershell
.\bootstrap.ps1 -Profile home -InstallOpenCode
```

Then register repositories:

```powershell
~/.agent-context/scripts/Register-Project.ps1 -Name "Jax" -Path "C:\Projects\Jax\jax-trading-assistant"
~/.agent-context/scripts/Register-Project.ps1 -Name "OSINT" -Path "C:\Projects\osint-security-platform"
```

The system works without Jev.

If you later want Jev:

```powershell
$env:JEV_API_KEY = "your-key-from-a-secret-store"
~/.agent-context/scripts/Enable-Jev.ps1
```

Test the adapter with non-sensitive content before routing any real workflow through it.
