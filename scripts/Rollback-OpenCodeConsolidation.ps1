[CmdletBinding()]
param(
    [string]$OpenCodeRoot = (Join-Path (Join-Path $HOME '.config') 'opencode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativePathCompat([string]$BasePath, [string]$FullPath) {
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([char[]]'\/')
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
        throw "Backup source not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        throw "Recovery staging path already exists: $Destination"
    }

    New-Item -ItemType Directory -Path $Destination -ErrorAction Stop | Out-Null

    foreach ($dir in @(Get-ChildItem -LiteralPath $Source -Recurse -Directory -ErrorAction Stop)) {
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
        throw "Recovery copy verification failed: source=$($sourceFiles.Count), destination=$($destFiles.Count)."
    }

    foreach ($file in $sourceFiles) {
        $rel = Get-RelativePathCompat $Source $file.FullName
        $dest = Join-Path $Destination $rel
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            throw "Recovery copy missing file: $dest"
        }
        if ((Get-FileSha256 $file.FullName) -ne (Get-FileSha256 $dest)) {
            throw "Recovery copy hash mismatch: $rel"
        }
    }

    return $sourceFiles.Count
}

if (-not (Test-Path -LiteralPath $OpenCodeRoot -PathType Container)) {
    throw "OpenCode root not found: $OpenCodeRoot"
}

$backups = @(Get-ChildItem -LiteralPath $OpenCodeRoot -Directory -Filter '_pre-context-spine-backup-*' -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending)
if ($backups.Count -eq 0) {
    throw "No pre-consolidation OpenCode backup was found inside: $OpenCodeRoot"
}

$backup = $backups[0]
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$recoveryStage = Join-Path $HOME ('.opencode-rollback-stage-' + $stamp)
$brokenCopy = Join-Path (Split-Path -Parent $OpenCodeRoot) ('opencode-context-spine-merged-' + $stamp)

Write-Host 'Using pre-consolidation backup:'
Write-Host "  $($backup.FullName)"
Write-Host ''
Write-Host 'Creating verified recovery copy outside the live OpenCode directory...'
$count = Copy-TreeVerified -Source $backup.FullName -Destination $recoveryStage
Write-Host "Recovery copy verified: $count files"

if (Test-Path -LiteralPath $brokenCopy) {
    throw "Preservation destination already exists: $brokenCopy"
}

Write-Host ''
Write-Host 'Preserving the current merged OpenCode directory (nothing is deleted)...'
Move-Item -LiteralPath $OpenCodeRoot -Destination $brokenCopy -ErrorAction Stop

try {
    Move-Item -LiteralPath $recoveryStage -Destination $OpenCodeRoot -ErrorAction Stop
}
catch {
    Write-Warning 'Restoring the merged OpenCode directory because replacement failed.'
    if ((-not (Test-Path -LiteralPath $OpenCodeRoot)) -and (Test-Path -LiteralPath $brokenCopy)) {
        Move-Item -LiteralPath $brokenCopy -Destination $OpenCodeRoot -ErrorAction SilentlyContinue
    }
    throw
}

Write-Host ''
Write-Host 'OPENCODE CONSOLIDATION ROLLBACK: PASSED'
Write-Host "Restored OpenCode root: $OpenCodeRoot"
Write-Host "Preserved merged copy: $brokenCopy"
Write-Host 'No folders were deleted.'
Write-Host 'The shadow and partial Context Spine folders were not changed.'

[pscustomobject]@{
    rolled_back = $true
    restored_root = $OpenCodeRoot
    restored_files = $count
    preserved_merged_copy = $brokenCopy
    deleted_anything = $false
}
