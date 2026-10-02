[CmdletBinding()]
param(
    [string]$OpenCodeRoot = (Join-Path (Join-Path $HOME '.config') 'opencode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileHashSafe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host 'OPENCODE STARTUP DIAGNOSTIC'
Write-Host '==========================='
Write-Host ''

$cmd = Get-Command opencode -ErrorAction SilentlyContinue
if ($null -eq $cmd) {
    Write-Host 'Executable found: NO'
} else {
    Write-Host 'Executable found: YES'
    Write-Host ("Executable path:  " + $cmd.Source)
}

Write-Host ''
if ($null -ne $cmd) {
    try {
        $versionOutput = & $cmd.Source --version 2>&1 | Out-String
        Write-Host 'Version command:   PASSED'
        Write-Host ("Version output:    " + $versionOutput.Trim())
    }
    catch {
        Write-Host 'Version command:   FAILED'
        Write-Host ("Version error:     " + $_.Exception.Message)
    }
}

Write-Host ''
Write-Host ("OpenCode root:      " + $OpenCodeRoot)
Write-Host ("OpenCode root exists: " + (Test-Path -LiteralPath $OpenCodeRoot -PathType Container))

$opencodeJson = Join-Path $OpenCodeRoot 'opencode.json'
$configJson = Join-Path $OpenCodeRoot 'config.json'
$agents = Join-Path $OpenCodeRoot 'AGENTS.md'
$marker = Join-Path $OpenCodeRoot '.context-spine-canonical.json'

Write-Host ''
Write-Host ("opencode.json exists: " + (Test-Path -LiteralPath $opencodeJson -PathType Leaf))
if (Test-Path -LiteralPath $opencodeJson -PathType Leaf) {
    try {
        $null = Get-Content -LiteralPath $opencodeJson -Raw | ConvertFrom-Json
        Write-Host 'opencode.json JSON:  VALID'
    }
    catch {
        Write-Host 'opencode.json JSON:  INVALID'
        Write-Host ("JSON error:          " + $_.Exception.Message)
    }
}

Write-Host ("config.json exists:   " + (Test-Path -LiteralPath $configJson -PathType Leaf))
if (Test-Path -LiteralPath $configJson -PathType Leaf) {
    try {
        $cfg = Get-Content -LiteralPath $configJson -Raw | ConvertFrom-Json
        Write-Host 'config.json JSON:    VALID'
        if ($null -ne $cfg.PSObject.Properties['profile']) { Write-Host ("Context profile:      " + $cfg.profile) }
        if ($null -ne $cfg.PSObject.Properties['model_provider']) { Write-Host ("Context model:        " + $cfg.model_provider) }
    }
    catch {
        Write-Host 'config.json JSON:    INVALID'
        Write-Host ("JSON error:          " + $_.Exception.Message)
    }
}

Write-Host ("AGENTS.md exists:     " + (Test-Path -LiteralPath $agents -PathType Leaf))
Write-Host ("Canonical marker:     " + (Test-Path -LiteralPath $marker -PathType Leaf))

$backups = @()
if (Test-Path -LiteralPath $OpenCodeRoot -PathType Container) {
    $backups = @(Get-ChildItem -LiteralPath $OpenCodeRoot -Directory -Filter '_pre-context-spine-backup-*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
}

Write-Host ''
Write-Host ("Pre-merge backups found: " + $backups.Count)

if ($backups.Count -gt 0) {
    $backup = $backups[0].FullName
    Write-Host ("Latest backup:          " + $backup)

    foreach ($name in @('opencode.json','AGENTS.md')) {
        $live = Join-Path $OpenCodeRoot $name
        $old = Join-Path $backup $name
        $liveHash = Get-FileHashSafe $live
        $oldHash = Get-FileHashSafe $old

        if ($null -eq $liveHash -and $null -eq $oldHash) {
            Write-Host ("$name comparison:    absent in both")
        }
        elseif ($null -eq $liveHash -or $null -eq $oldHash) {
            Write-Host ("$name comparison:    presence differs")
        }
        elseif ($liveHash -eq $oldHash) {
            Write-Host ("$name comparison:    UNCHANGED")
        }
        else {
            Write-Host ("$name comparison:    CHANGED")
        }
    }
}

$spineCommands = @()
$commandsRoot = Join-Path $OpenCodeRoot 'commands'
if (Test-Path -LiteralPath $commandsRoot -PathType Container) {
    $spineCommands = @(Get-ChildItem -LiteralPath $commandsRoot -Filter 'spine-*.md' -File -ErrorAction SilentlyContinue)
}
Write-Host ("spine-* commands found: " + $spineCommands.Count)

$memoryRoot = Join-Path $OpenCodeRoot 'memory'
Write-Host ("memory folder exists:    " + (Test-Path -LiteralPath $memoryRoot -PathType Container))

Write-Host ''
Write-Host 'DIAGNOSTIC COMPLETE - NO FILES WERE MODIFIED'
