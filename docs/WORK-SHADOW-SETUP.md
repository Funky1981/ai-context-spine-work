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


## Step 2 — Prepare the isolated shadow installer

Copy `scripts/Install-WorkShadow.ps1` from GitHub Raw to:

```text
C:\Temp\ContextSpine\Install-WorkShadow.ps1
```

Do not run it yet.

The script is hard-wired to use:

```text
%USERPROFILE%\.context-spine-shadow
```

It refuses to use either the live OpenCode directory or the existing `.agent-context` directory as its target.


## Step 3 — Verify the copied shadow installer

Run:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path "C:\Temp\ContextSpine\Install-WorkShadow.ps1"),
    [ref]$null,
    [ref]$errors
) | Out-Null

$errors
```

Expected result: nothing is printed. If any parser error is shown, stop and do not run the shadow installer.


## Step 4 — Verify your real context in the shadow copy

Copy `scripts/Verify-WorkShadowContext.ps1` from GitHub Raw to:

```text
C:\Temp\ContextSpine\Verify-WorkShadowContext.ps1
```

Then run:

```powershell
& "C:\Temp\ContextSpine\Verify-WorkShadowContext.ps1"
```

Expected final result:

```text
WORK SHADOW CONTEXT VERIFICATION: PASSED
```

The verifier is read-only. It compares the live OpenCode context with the shadow import using SHA-256 hashes and reports memory, project, command, and skill counts. Stop if it reports any failure.
