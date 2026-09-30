# Work Shadow Setup

This procedure protects the existing OpenCode setup and proves Context Spine in isolation before any integration.

## Safety rules

- Treat `%USERPROFILE%\.config\opencode\` as read-only during shadow setup.
- Do not delete or modify the existing `%USERPROFILE%\.agent-context\` partial install yet.
- Do not use `-Force` against the live setup.
- Do not enable Jev or any external AI provider on the work profile.
- The work profile remains GLM-only.

## Step 1 — Back up and verify the existing OpenCode setup

Copy `scripts/Backup-ExistingOpenCode.ps1` from GitHub Raw to:

```text
C:\Temp\ContextSpine\Backup-ExistingOpenCode.ps1
```

Then run:

```powershell
& "C:\Temp\ContextSpine\Backup-ExistingOpenCode.ps1"
```

Expected success output includes:

```text
BACKUP VERIFIED: PASSED
Original OpenCode setup was not modified.
```

Stop if any error is reported. Do not continue to the shadow installation until the backup reports `BACKUP VERIFIED: PASSED`.


## Step 1A — If Step 1 prints nothing

Run this exact command:

```powershell
Get-Item "C:\Temp\ContextSpine\Backup-ExistingOpenCode.ps1" | Select-Object FullName,Length,LastWriteTime
```

Expected result: one row showing the full path, a non-zero file length, and a timestamp.

If PowerShell reports that the path does not exist, stop. Do not run any other Context Spine command.
