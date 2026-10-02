[CmdletBinding()]
param(
    [string]$OpenCodeRoot = (Join-Path (Join-Path $HOME '.config') 'opencode'),
    [string]$ShadowRoot = (Join-Path $HOME '.context-spine-shadow'),
    [string]$PartialRoot = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
}

function Get-RelativePathCompat([string]$BasePath, [string]$FullPath) {
    $base = (Get-NormalizedPath $BasePath)
    $full = [System.IO.Path]::GetFullPath($FullPath)
    if ($full.Length -le $base.Length) { return (Split-Path -Leaf $full) }
    return $full.Substring($base.Length).TrimStart([char[]]'\/')
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Copy-TreeVerified {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Copy source directory not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        throw "Copy destination already exists: $Destination"
    }

    New-Item -ItemType Directory -Path $Destination -ErrorAction Stop | Out-Null

    $sourceDirs = @(Get-ChildItem -LiteralPath $Source -Recurse -Directory -ErrorAction Stop)
    foreach ($dir in $sourceDirs) {
        $rel = Get-RelativePathCompat $Source $dir.FullName
        New-Item -ItemType Directory -Force -Path (Join-Path $Destination $rel) | Out-Null
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction Stop)
    foreach ($file in $sourceFiles) {
        $rel = Get-RelativePathCompat $Source $file.FullName
        $dest = Join-Path $Destination $rel
        $parent = Split-Path -Parent $dest
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item -LiteralPath $file.FullName -Destination $dest -ErrorAction Stop
    }

    $destFiles = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -ErrorAction Stop)
    if ($sourceFiles.Count -ne $destFiles.Count) {
        throw "Verified copy failed: source has $($sourceFiles.Count) files; destination has $($destFiles.Count)."
    }

    foreach ($file in $sourceFiles) {
        $rel = Get-RelativePathCompat $Source $file.FullName
        $dest = Join-Path $Destination $rel
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            throw "Verified copy failed; destination file missing: $dest"
        }
        if ((Get-FileSha256 $file.FullName) -ne (Get-FileSha256 $dest)) {
            throw "Verified copy failed; hash mismatch: $rel"
        }
    }

    return $sourceFiles.Count
}

function Copy-ManagedTree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    $sourceDirs = @(Get-ChildItem -LiteralPath $Source -Recurse -Directory -ErrorAction Stop)
    foreach ($dir in $sourceDirs) {
        $rel = Get-RelativePathCompat $Source $dir.FullName
        New-Item -ItemType Directory -Force -Path (Join-Path $Destination $rel) | Out-Null
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction Stop)
    foreach ($file in $sourceFiles) {
        $rel = Get-RelativePathCompat $Source $file.FullName
        $dest = Join-Path $Destination $rel
        $parent = Split-Path -Parent $dest
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force -ErrorAction Stop
        if ((Get-FileSha256 $file.FullName) -ne (Get-FileSha256 $dest)) {
            throw "Managed copy hash mismatch: $dest"
        }
    }
}

$openCode = Get-NormalizedPath $OpenCodeRoot
$shadow = Get-NormalizedPath $ShadowRoot
$partial = Get-NormalizedPath $PartialRoot

if ($openCode -eq $shadow -or $openCode -eq $partial -or $shadow -eq $partial) {
    throw 'OpenCode, shadow and partial Context Spine paths must be distinct.'
}
if (-not (Test-Path -LiteralPath $OpenCodeRoot -PathType Container)) {
    throw "OpenCode root not found: $OpenCodeRoot"
}
if (-not (Test-Path -LiteralPath $ShadowRoot -PathType Container)) {
    throw "Verified shadow root not found: $ShadowRoot"
}

$canonicalMarker = Join-Path $OpenCodeRoot '.context-spine-canonical.json'
if (Test-Path -LiteralPath $canonicalMarker -PathType Leaf) {
    throw "This OpenCode folder is already marked as the canonical Context Spine root: $canonicalMarker"
}

$shadowHealthScript = Join-Path $ShadowRoot 'scripts\Test-Workspace.ps1'
if (-not (Test-Path -LiteralPath $shadowHealthScript -PathType Leaf)) {
    throw "Shadow health script missing: $shadowHealthScript"
}
$shadowHealth = & $shadowHealthScript -Root $ShadowRoot
if (-not [bool]$shadowHealth.healthy) {
    throw 'Shadow Context Spine is not healthy. Consolidation stopped before changing OpenCode.'
}
if ([string]$shadowHealth.profile -ne 'work' -or [string]$shadowHealth.model_provider -ne 'glm') {
    throw 'Shadow Context Spine is not the expected work/GLM profile.'
}
if ([bool]$shadowHealth.external_ai_allowed -or [bool]$shadowHealth.jev_enabled) {
    throw 'Shadow Context Spine violates the work safety profile. Consolidation stopped.'
}

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backupRoot = Join-Path $HOME ("opencode-pre-consolidation-" + $stamp)
$stageRoot = Join-Path $HOME (".context-spine-consolidation-stage-" + $stamp)
$oldMemoryRoot = Join-Path $OpenCodeRoot ("memory.pre-context-spine-" + $stamp)
$newMemoryRoot = Join-Path $OpenCodeRoot ("memory.context-spine-new-" + $stamp)

Write-Host 'Creating verified pre-consolidation backup...'
$backupCount = Copy-TreeVerified -Source $OpenCodeRoot -Destination $backupRoot
Write-Host "Backup verified: $backupCount files"

Write-Host 'Creating consolidation staging copy from the verified shadow workspace...'
$stageCount = Copy-TreeVerified -Source $ShadowRoot -Destination $stageRoot
Write-Host "Shadow staging copy verified: $stageCount files"

$stageImport = Join-Path $stageRoot 'scripts\Import-ExistingContext.ps1'
if (-not (Test-Path -LiteralPath $stageImport -PathType Leaf)) {
    throw "Staged import script missing: $stageImport"
}

Write-Host 'Importing the exact pre-consolidation OpenCode backup into staging...'
& $stageImport -Source $backupRoot -Root $stageRoot | Out-Host

$stageHealthScript = Join-Path $stageRoot 'scripts\Test-Workspace.ps1'
$stageHealth = & $stageHealthScript -Root $stageRoot
if (-not [bool]$stageHealth.healthy) {
    throw 'Staged Context Spine is not healthy. Live OpenCode has not been consolidated.'
}

$stageMemory = Join-Path $stageRoot 'memory'
if (-not (Test-Path -LiteralPath $stageMemory -PathType Container)) {
    throw "Staged memory directory missing: $stageMemory"
}

Write-Host 'Preparing verified canonical memory tree inside OpenCode...'
$memoryCount = Copy-TreeVerified -Source $stageMemory -Destination $newMemoryRoot

$liveMemory = Join-Path $OpenCodeRoot 'memory'
if (Test-Path -LiteralPath $liveMemory -PathType Container) {
    Move-Item -LiteralPath $liveMemory -Destination $oldMemoryRoot -ErrorAction Stop
}
Move-Item -LiteralPath $newMemoryRoot -Destination $liveMemory -ErrorAction Stop

foreach ($dirName in @('context','index','imports','migrations','projects','scripts','integration')) {
    $sourceDir = Join-Path $stageRoot $dirName
    $destDir = Join-Path $OpenCodeRoot $dirName
    Copy-ManagedTree -Source $sourceDir -Destination $destDir
}

$stageSkills = Join-Path $stageRoot 'skills'
$liveSkills = Join-Path $OpenCodeRoot 'skills'
Copy-ManagedTree -Source $stageSkills -Destination $liveSkills

$stageConfig = Join-Path $stageRoot 'config.json'
if (-not (Test-Path -LiteralPath $stageConfig -PathType Leaf)) { throw 'Staged config.json is missing.' }
Copy-Item -LiteralPath $stageConfig -Destination (Join-Path $OpenCodeRoot 'config.json') -Force

$stageReadme = Join-Path $stageRoot 'README.md'
if (Test-Path -LiteralPath $stageReadme -PathType Leaf) {
    Copy-Item -LiteralPath $stageReadme -Destination (Join-Path $OpenCodeRoot 'CONTEXT-SPINE.md') -Force
}

$commandsRoot = Join-Path $OpenCodeRoot 'commands'
New-Item -ItemType Directory -Force -Path $commandsRoot | Out-Null

$commandMap = [ordered]@{
    'spine-memory-status.md' = @'
---
description: Read Context Spine memory status from the canonical OpenCode workspace
---

Use the canonical work Context Spine at `%USERPROFILE%\.config\opencode`.

For historical memory retrieval use:
`%USERPROFILE%\.config\opencode\scripts\Search-Memory.ps1 -Root "%USERPROFILE%\.config\opencode"`

For workspace health use:
`%USERPROFILE%\.config\opencode\scripts\Test-Workspace.ps1 -Root "%USERPROFILE%\.config\opencode"`

Repository source overrides historical memory when they conflict.
'@

    'spine-memory-search.md' = @'
---
description: Search canonical Context Spine memory
---

Search for `$ARGUMENTS` by running:
`%USERPROFILE%\.config\opencode\scripts\Search-Memory.ps1 -Root "%USERPROFILE%\.config\opencode" -Pattern "$ARGUMENTS" -IncludeImports`

Read relevant matched files before drawing conclusions.
Repository source overrides historical memory when they conflict.
'@

    'spine-context-search.md' = @'
---
description: Search source for a registered Context Spine project
---

Use:
`%USERPROFILE%\.config\opencode\scripts\Search-Context.ps1 -Root "%USERPROFILE%\.config\opencode"`

Read matched source files before making implementation conclusions.
'@

    'spine-context-health.md' = @'
---
description: Check the canonical Context Spine workspace
---

Run:
`%USERPROFILE%\.config\opencode\scripts\Test-Workspace.ps1 -Root "%USERPROFILE%\.config\opencode"`

Report the health result exactly. Do not change provider configuration.
'@
}

foreach ($name in $commandMap.Keys) {
    Set-Content -LiteralPath (Join-Path $commandsRoot $name) -Value $commandMap[$name] -Encoding UTF8
}

$agentsPath = Join-Path $OpenCodeRoot 'AGENTS.md'
$startMarker = '<!-- context-spine-integration:start -->'
$endMarker = '<!-- context-spine-integration:end -->'
$integrationBlock = @"
$startMarker
## Context Spine

Canonical local Context Spine root: `%USERPROFILE%\.config\opencode`.

- Use the repository as the authoritative source for implementation truth.
- Use `scripts\Search-Memory.ps1` for durable/historical memory.
- Use `scripts\Search-Context.ps1` for registered repository source.
- Use `scripts\Test-Workspace.ps1` to verify Context Spine health.
- Imported history is additive and should remain traceable.
- Work profile is GLM-only. External AI is disabled and Jev remains disabled unless formally approved.
- Do not store credentials, tokens or secrets in persistent memory.

$endMarker
"@

if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
    $agentsText = Get-Content -LiteralPath $agentsPath -Raw
    if ($null -eq $agentsText) { $agentsText = '' }
    if ($agentsText.Contains($startMarker)) {
        $pattern = [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
        $agentsText = [regex]::Replace($agentsText, $pattern, $integrationBlock, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        Set-Content -LiteralPath $agentsPath -Value $agentsText -Encoding UTF8
    }
    else {
        Add-Content -LiteralPath $agentsPath -Value ("`r`n`r`n" + $integrationBlock) -Encoding UTF8
    }
}
else {
    Set-Content -LiteralPath $agentsPath -Value $integrationBlock -Encoding UTF8
}

$liveHealthScript = Join-Path $OpenCodeRoot 'scripts\Test-Workspace.ps1'
$liveHealth = & $liveHealthScript -Root $OpenCodeRoot
if (-not [bool]$liveHealth.healthy) {
    throw "Consolidated OpenCode Context Spine failed health verification. Rollback backup remains at: $backupRoot"
}
if ([string]$liveHealth.profile -ne 'work' -or [string]$liveHealth.model_provider -ne 'glm') {
    throw 'Consolidated Context Spine is not the expected work/GLM profile.'
}
if ([bool]$liveHealth.external_ai_allowed -or [bool]$liveHealth.jev_enabled) {
    throw 'Consolidated Context Spine violates the work safety profile.'
}

$internalBackup = Join-Path $OpenCodeRoot ("_pre-context-spine-backup-" + $stamp)
Move-Item -LiteralPath $backupRoot -Destination $internalBackup -ErrorAction Stop

$marker = [ordered]@{
    schema = 'context-spine-canonical-opencode-v1'
    consolidated_at_utc = [DateTime]::UtcNow.ToString('o')
    canonical_root = $OpenCodeRoot
    source_shadow_root = $ShadowRoot
    partial_root = $PartialRoot
    staging_root = $stageRoot
    pre_consolidation_backup = $internalBackup
    pre_consolidation_memory = if (Test-Path -LiteralPath $oldMemoryRoot) { $oldMemoryRoot } else { $null }
    memory_files_installed = $memoryCount
    profile = [string]$liveHealth.profile
    model_provider = [string]$liveHealth.model_provider
    external_ai_allowed = [bool]$liveHealth.external_ai_allowed
    jev_enabled = [bool]$liveHealth.jev_enabled
    cleanup_ready = $false
}
$marker | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $canonicalMarker -Encoding UTF8

Write-Host ''
Write-Host 'CONTEXT SPINE CONSOLIDATION: PASSED'
Write-Host "Canonical root: $OpenCodeRoot"
Write-Host "Memory files installed: $memoryCount"
Write-Host "Profile: $($liveHealth.profile)"
Write-Host "Model provider: $($liveHealth.model_provider)"
Write-Host "External AI allowed: $($liveHealth.external_ai_allowed)"
Write-Host "Jev enabled: $($liveHealth.jev_enabled)"
Write-Host "Rollback backup retained inside OpenCode: $internalBackup"
Write-Host "Old memory retained temporarily: $oldMemoryRoot"
Write-Host "Shadow and partial installs have NOT been deleted yet."
Write-Host 'Run cleanup only after testing the canonical OpenCode Context Spine.'

[pscustomobject]@{
    consolidated = $true
    canonical_root = $OpenCodeRoot
    healthy = [bool]$liveHealth.healthy
    profile = [string]$liveHealth.profile
    model_provider = [string]$liveHealth.model_provider
    external_ai_allowed = [bool]$liveHealth.external_ai_allowed
    jev_enabled = [bool]$liveHealth.jev_enabled
    backup = $internalBackup
    old_memory = $oldMemoryRoot
    stage = $stageRoot
    shadow_retained = (Test-Path -LiteralPath $ShadowRoot)
    partial_retained = (Test-Path -LiteralPath $PartialRoot)
}
