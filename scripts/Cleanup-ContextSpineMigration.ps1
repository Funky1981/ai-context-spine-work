[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$OpenCodeRoot = (Join-Path (Join-Path $HOME '.config') 'opencode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
}

function Is-Under([string]$Child, [string]$Parent) {
    $c = Normalize $Child
    $p = Normalize $Parent
    return $c.StartsWith($p + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

$canonical = Normalize $OpenCodeRoot
$markerPath = Join-Path $canonical '.context-spine-canonical.json'
$healthScript = Join-Path $canonical 'scripts\Test-Workspace.ps1'

if (-not (Test-Path -LiteralPath $canonical -PathType Container)) { throw "Canonical OpenCode root not found: $canonical" }
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw "Canonical Context Spine marker not found: $markerPath" }
if (-not (Test-Path -LiteralPath $healthScript -PathType Leaf)) { throw "Canonical health script not found: $healthScript" }

$marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
$health = & $healthScript -Root $canonical

if (-not [bool]$health.healthy) { throw 'Canonical OpenCode Context Spine is not healthy. Cleanup refused.' }
if ([string]$health.profile -ne 'work') { throw "Unexpected profile '$($health.profile)'. Cleanup refused." }
if ([string]$health.model_provider -ne 'glm') { throw "Unexpected model provider '$($health.model_provider)'. Cleanup refused." }
if ([bool]$health.external_ai_allowed) { throw 'External AI is enabled. Cleanup refused.' }
if ([bool]$health.jev_enabled) { throw 'Jev is enabled. Cleanup refused.' }

$memoryRoot = Join-Path $canonical 'memory'
$memoryFiles = @(Get-ChildItem -LiteralPath $memoryRoot -Recurse -File -ErrorAction Stop)
if ($memoryFiles.Count -eq 0) { throw 'Canonical memory tree is empty. Cleanup refused.' }

$backupPath = [string]$marker.pre_consolidation_backup
if ([string]::IsNullOrWhiteSpace($backupPath) -or -not (Test-Path -LiteralPath $backupPath -PathType Container)) {
    throw 'Canonical pre-consolidation rollback backup is missing. Cleanup refused.'
}
if (-not (Is-Under $backupPath $canonical)) { throw 'Rollback backup is not inside the canonical OpenCode folder. Cleanup refused.' }

$targets = @()

$shadow = Join-Path $HOME '.context-spine-shadow'
if (Test-Path -LiteralPath $shadow -PathType Container) {
    $targets += [pscustomobject]@{ path=$shadow; reason='verified shadow installation now superseded by canonical OpenCode root' }
}

$partial = Join-Path $HOME '.agent-context'
if (Test-Path -LiteralPath $partial -PathType Container) {
    $targets += [pscustomobject]@{ path=$partial; reason='failed/partial pre-shadow Context Spine installation' }
}

$stage = [string]$marker.staging_root
if (-not [string]::IsNullOrWhiteSpace($stage) -and (Test-Path -LiteralPath $stage -PathType Container)) {
    $stageName = Split-Path -Leaf $stage
    if (-not $stageName.StartsWith('.context-spine-consolidation-stage-')) { throw "Unexpected staging folder name: $stage" }
    if (-not (Is-Under $stage $HOME)) { throw "Staging folder is outside HOME: $stage" }
    $targets += [pscustomobject]@{ path=$stage; reason='completed consolidation staging copy' }
}

$oldMemory = [string]$marker.pre_consolidation_memory
if (-not [string]::IsNullOrWhiteSpace($oldMemory) -and (Test-Path -LiteralPath $oldMemory -PathType Container)) {
    $oldName = Split-Path -Leaf $oldMemory
    if (-not $oldName.StartsWith('memory.pre-context-spine-')) { throw "Unexpected old-memory folder name: $oldMemory" }
    if (-not (Is-Under $oldMemory $canonical)) { throw "Old-memory folder is outside canonical OpenCode: $oldMemory" }
    $backupMemory = Join-Path $backupPath 'memory'
    if (-not (Test-Path -LiteralPath $backupMemory -PathType Container)) { throw 'Rollback backup does not contain the original memory folder. Cleanup refused.' }
    $targets += [pscustomobject]@{ path=$oldMemory; reason='duplicate pre-consolidation memory retained in full rollback backup' }
}

Write-Host ''
Write-Host 'CONTEXT SPINE CLEANUP SAFETY CHECK: PASSED'
Write-Host "Canonical root: $canonical"
Write-Host "Canonical memory files: $($memoryFiles.Count)"
Write-Host "Rollback backup retained: $backupPath"
Write-Host ''

if ($targets.Count -eq 0) {
    Write-Host 'No redundant migration folders were found.'
    exit 0
}

Write-Host 'Redundant folders:'
foreach ($target in $targets) {
    Write-Host "  $($target.path)"
    Write-Host "    $($target.reason)"
}

if (-not $Apply) {
    Write-Host ''
    Write-Host 'DRY RUN ONLY - NOTHING DELETED'
    Write-Host 'Run again with -Apply only if this list is correct.'
    exit 0
}

foreach ($target in $targets) {
    $resolved = Normalize $target.path
    if ($resolved -eq $canonical) { throw 'Refusing to delete canonical OpenCode root.' }
    if ($resolved -eq (Normalize $backupPath)) { throw 'Refusing to delete retained rollback backup.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
}

$healthAfter = & $healthScript -Root $canonical
if (-not [bool]$healthAfter.healthy) { throw 'Canonical Context Spine became unhealthy after cleanup.' }

$marker.cleanup_ready = $true
$marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $markerPath -Encoding UTF8

Write-Host ''
Write-Host 'CONTEXT SPINE MIGRATION CLEANUP: PASSED'
Write-Host "Canonical root retained: $canonical"
Write-Host "Rollback backup retained: $backupPath"
Write-Host 'Canonical memory, commands, scripts and configuration were not deleted.'
