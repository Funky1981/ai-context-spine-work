[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Source,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SafeSlug([string]$Value) {
    $leaf = Split-Path -Leaf $Value
    if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = 'context' }
    $slug = $leaf.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    $suffix = (Get-StringSha256 $Value).Substring(0, 8)
    return "$slug-$suffix"
}

function Get-RelativePathCompat([string]$BasePath, [string]$FullPath) {
    $base = $BasePath.TrimEnd([char[]]"\/")
    if ($FullPath.Length -le $base.Length) { return (Split-Path -Leaf $FullPath) }
    return $FullPath.Substring($base.Length).TrimStart([char[]]"\/")
}

function Copy-PreservingConflict {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$SourceSlug
    )

    $parent = Split-Path -Parent $DestinationPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $sourceHash = Get-FileSha256 $SourcePath
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
        return [pscustomobject]@{ action = 'copied'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $targetHash = Get-FileSha256 $DestinationPath
    if ($targetHash -eq $sourceHash) {
        return [pscustomobject]@{ action = 'identical-skip'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $dir = Split-Path -Parent $DestinationPath
    $name = [System.IO.Path]::GetFileNameWithoutExtension($DestinationPath)
    $ext = [System.IO.Path]::GetExtension($DestinationPath)
    $conflictName = "$name.imported-$SourceSlug-$($sourceHash.Substring(0,8))$ext"
    $conflictPath = Join-Path $dir $conflictName

    if (-not (Test-Path -LiteralPath $conflictPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $conflictPath
        return [pscustomobject]@{ action = 'conflict-preserved'; path = $conflictPath; sha256 = $sourceHash }
    }

    if ((Get-FileSha256 $conflictPath) -eq $sourceHash) {
        return [pscustomobject]@{ action = 'conflict-identical-skip'; path = $conflictPath; sha256 = $sourceHash }
    }

    throw "Unexpected hash collision while importing '$SourcePath'."
}

function Merge-GlobalMemory {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$SourceDisplay
    )

    $sourceText = Get-Content -LiteralPath $SourcePath -Raw
    $sourceHash = Get-FileSha256 $SourcePath
    $marker = "<!-- context-spine-import sha256:$sourceHash -->"

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        $parent = Split-Path -Parent $DestinationPath
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
        return [pscustomobject]@{ action = 'canonical-created'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $current = Get-Content -LiteralPath $DestinationPath -Raw
    if ($current.Contains($marker)) {
        return [pscustomobject]@{ action = 'canonical-already-imported'; path = $DestinationPath; sha256 = $sourceHash }
    }

    if ((Get-FileSha256 $DestinationPath) -eq $sourceHash) {
        return [pscustomobject]@{ action = 'canonical-identical-skip'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $block = @"

$marker
## Imported legacy context

Source: $SourceDisplay
Imported UTC: $([DateTime]::UtcNow.ToString('o'))

$sourceText
<!-- /context-spine-import -->
"@
    Add-Content -LiteralPath $DestinationPath -Value $block -Encoding UTF8
    return [pscustomobject]@{ action = 'canonical-appended'; path = $DestinationPath; sha256 = $sourceHash }
}

$rootFull = [System.IO.Path]::GetFullPath($Root)
$importsRoot = Join-Path $Root 'imports'
$migrationsRoot = Join-Path $Root 'migrations'
New-Item -ItemType Directory -Force -Path $importsRoot, $migrationsRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]

foreach ($sourceInput in $Source) {
    if ([string]::IsNullOrWhiteSpace($sourceInput)) { continue }
    if (-not (Test-Path -LiteralPath $sourceInput -PathType Container)) {
        Write-Warning "Legacy context source not found: $sourceInput"
        continue
    }

    $sourceRoot = (Resolve-Path -LiteralPath $sourceInput).Path
    if ([System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('\') -eq $rootFull.TrimEnd('\')) {
        Write-Host "SKIP import source because it is the active Context Spine root: $sourceRoot"
        continue
    }

    $sourceSlug = Get-SafeSlug $sourceRoot
    $rawRoot = Join-Path $importsRoot $sourceSlug
    New-Item -ItemType Directory -Force -Path $rawRoot | Out-Null

    $memoryCandidate = Join-Path $sourceRoot 'memory'
    $isOpenCodeRoot = Test-Path -LiteralPath $memoryCandidate -PathType Container
    $memoryRoot = if ($isOpenCodeRoot) { $memoryCandidate } else { $sourceRoot }

    $snapshotFiles = @(if ($isOpenCodeRoot) {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $rel = Get-RelativePathCompat $sourceRoot $_.FullName
                $rel -match '^(memory|commands|skills)[\\/]' -or $_.Name -in @('AGENTS.md','opencode.json')
            }
    }
    else {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue
    })

    $actions = New-Object System.Collections.Generic.List[object]

    foreach ($file in $snapshotFiles) {
        $relative = Get-RelativePathCompat $sourceRoot $file.FullName
        $dest = Join-Path $rawRoot $relative
        $action = Copy-PreservingConflict -SourcePath $file.FullName -DestinationPath $dest -SourceSlug $sourceSlug
        $actions.Add([ordered]@{
            scope = 'raw-snapshot'
            source = $file.FullName
            destination = $action.path
            action = $action.action
            sha256 = $action.sha256
        })
    }

    foreach ($name in @('MEMORY.md','lessons.md','preferences.md')) {
        $sourcePath = Join-Path $memoryRoot $name
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            $destPath = Join-Path (Join-Path $Root 'memory') $name
            $action = Merge-GlobalMemory -SourcePath $sourcePath -DestinationPath $destPath -SourceDisplay $sourcePath
            $actions.Add([ordered]@{
                scope = 'canonical-global'
                source = $sourcePath
                destination = $action.path
                action = $action.action
                sha256 = $action.sha256
            })
        }
    }

    $legacyProjects = Join-Path $memoryRoot 'projects'
    if (Test-Path -LiteralPath $legacyProjects -PathType Container) {
        Get-ChildItem -LiteralPath $legacyProjects -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $relative = Get-RelativePathCompat $legacyProjects $_.FullName
            $dest = Join-Path (Join-Path $Root 'memory/projects') $relative
            $action = Copy-PreservingConflict -SourcePath $_.FullName -DestinationPath $dest -SourceSlug $sourceSlug
            $actions.Add([ordered]@{
                scope = 'canonical-project'
                source = $_.FullName
                destination = $action.path
                action = $action.action
                sha256 = $action.sha256
            })
        }
    }

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $manifestPath = Join-Path $migrationsRoot ("import-$stamp-$sourceSlug.json")
    $manifest = [ordered]@{
        schema = 'context-spine-import-v1'
        imported_at_utc = [DateTime]::UtcNow.ToString('o')
        source_root = $sourceRoot
        source_slug = $sourceSlug
        source_preserved = $true
        raw_snapshot_root = $rawRoot
        actions = $actions
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    $results.Add([pscustomobject]@{
        source = $sourceRoot
        raw_snapshot = $rawRoot
        manifest = $manifestPath
        actions = $actions.Count
        source_preserved = $true
    })

    Write-Host "Imported legacy context from: $sourceRoot"
    Write-Host "Original source was not modified or deleted."
    Write-Host "Audit manifest: $manifestPath"

    $verifier = Join-Path $PSScriptRoot 'Test-ImportedContext.ps1'
    if (Test-Path -LiteralPath $verifier -PathType Leaf) {
        & $verifier -ManifestPath $manifestPath | Out-Host
        Write-Host "Import verification: PASSED"
    }
    else {
        Write-Warning "Test-ImportedContext.ps1 was not found; run an import verification after installing the full Context Spine."
    }
}

$results
