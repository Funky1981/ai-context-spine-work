[CmdletBinding()]
param(
    [string]$Source = (Join-Path (Join-Path $HOME '.config') 'opencode'),
    [string]$ShadowRoot = (Join-Path $HOME '.context-spine-shadow')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-RelativePathCompat([string]$BasePath, [string]$FullPath) {
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([char[]]'\/')
    $full = [System.IO.Path]::GetFullPath($FullPath)
    if ($full.Length -le $base.Length) { return (Split-Path -Leaf $full) }
    return $full.Substring($base.Length).TrimStart([char[]]'\/')
}

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Live OpenCode source not found: $Source"
}
if (-not (Test-Path -LiteralPath $ShadowRoot -PathType Container)) {
    throw "Shadow Context Spine not found: $ShadowRoot"
}

$manifestDir = Join-Path $ShadowRoot 'migrations'
$latestManifest = @(Get-ChildItem -LiteralPath $manifestDir -Filter 'import-*.json' -File -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
if ($latestManifest.Count -eq 0) { throw "No import manifest found under: $manifestDir" }

$manifestPath = $latestManifest[0].FullName
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$actions = @($manifest.actions)

$sourceResolved = (Resolve-Path -LiteralPath $Source).Path
$manifestSource = if ($null -ne $manifest.PSObject.Properties['source_root']) { [string]$manifest.source_root } else { '' }
if ([string]::IsNullOrWhiteSpace($manifestSource)) { throw "Import manifest has no source_root: $manifestPath" }
if ([System.IO.Path]::GetFullPath($manifestSource).TrimEnd([char[]]'\/') -ne [System.IO.Path]::GetFullPath($sourceResolved).TrimEnd([char[]]'\/')) {
    throw "Latest shadow import manifest does not point to the live OpenCode source. Manifest source: $manifestSource"
}

$expected = @(
    Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction Stop |
        Where-Object {
            $rel = Get-RelativePathCompat $Source $_.FullName
            $rel -match '^(memory|commands|skills)[\\/]' -or $_.Name -in @('AGENTS.md','opencode.json')
        }
)

$rawActions = @($actions | Where-Object { $_.scope -eq 'raw-snapshot' })
$failures = @()

foreach ($file in $expected) {
    $sourcePath = $file.FullName
    $sourceHash = Get-FileSha256 $sourcePath
    $matches = @($rawActions | Where-Object { $_.source -eq $sourcePath })
    if ($matches.Count -ne 1) {
        $failures += "Expected exactly one raw snapshot action for: $sourcePath"
        continue
    }
    $action = $matches[0]
    if (-not (Test-Path -LiteralPath $action.destination -PathType Leaf)) {
        $failures += "Shadow copy missing: $($action.destination)"
        continue
    }
    $destHash = Get-FileSha256 $action.destination
    if ($sourceHash -ne $destHash) {
        $failures += "Hash mismatch for: $sourcePath"
    }
}

if ($rawActions.Count -ne $expected.Count) {
    $failures += "Raw snapshot count mismatch. Live=$($expected.Count), Shadow=$($rawActions.Count)"
}

$memoryFiles = @($expected | Where-Object { (Get-RelativePathCompat $Source $_.FullName) -match '^memory[\\/]' })
$projectFiles = @($memoryFiles | Where-Object { (Get-RelativePathCompat $Source $_.FullName) -match '^memory[\\/]projects[\\/]' })
$commandFiles = @($expected | Where-Object { (Get-RelativePathCompat $Source $_.FullName) -match '^commands[\\/]' })
$skillFiles = @($expected | Where-Object { (Get-RelativePathCompat $Source $_.FullName) -match '^skills[\\/]' })
$otherFiles = @($expected | Where-Object {
    $rel = Get-RelativePathCompat $Source $_.FullName
    $rel -notmatch '^(memory|commands|skills)[\\/]'
})

$canonicalChecks = @()
foreach ($name in @('MEMORY.md','lessons.md','preferences.md')) {
    $live = Join-Path (Join-Path $Source 'memory') $name
    if (Test-Path -LiteralPath $live -PathType Leaf) {
        $canonical = Join-Path (Join-Path $ShadowRoot 'memory') $name
        $ok = Test-Path -LiteralPath $canonical -PathType Leaf
        $canonicalChecks += [pscustomobject]@{ name=$name; present_in_live=$true; present_in_shadow=$ok }
        if (-not $ok) { $failures += "Canonical shadow memory missing: $canonical" }
    }
}

$canonicalProjectRoot = Join-Path (Join-Path $ShadowRoot 'memory') 'projects'
$canonicalProjectFiles = @(if (Test-Path -LiteralPath $canonicalProjectRoot -PathType Container) { Get-ChildItem -LiteralPath $canonicalProjectRoot -Recurse -File -ErrorAction Stop } else { @() })

$verified = ($failures.Count -eq 0)

Write-Host ""
Write-Host "WORK SHADOW CONTEXT VERIFICATION"
Write-Host "Live source:    $Source"
Write-Host "Shadow root:    $ShadowRoot"
Write-Host "Manifest:       $manifestPath"
Write-Host ""
Write-Host "Files preserved by category:"
Write-Host "  Memory files:       $($memoryFiles.Count)"
Write-Host "  Project files:      $($projectFiles.Count)"
Write-Host "  Command files:      $($commandFiles.Count)"
Write-Host "  Skill files:        $($skillFiles.Count)"
Write-Host "  Other config files: $($otherFiles.Count)"
Write-Host "  Total verified:     $($expected.Count)"
Write-Host ""
Write-Host "Canonical project files now in shadow: $($canonicalProjectFiles.Count)"

if ($projectFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Project context found:"
    $projectRoots = @($projectFiles | ForEach-Object {
        $rel = Get-RelativePathCompat (Join-Path (Join-Path $Source 'memory') 'projects') $_.FullName
        ($rel -split '[\\/]')[0]
    } | Sort-Object -Unique)
    foreach ($project in $projectRoots) { Write-Host "  - $project" }
}

if ($commandFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Commands found:"
    foreach ($cmd in $commandFiles) { Write-Host "  - $(Get-RelativePathCompat $Source $cmd.FullName)" }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "VERIFICATION FAILURES:"
    foreach ($failure in $failures) { Write-Host "  - $failure" }
    throw "WORK SHADOW CONTEXT VERIFICATION: FAILED"
}

Write-Host ""
Write-Host "WORK SHADOW CONTEXT VERIFICATION: PASSED"
Write-Host "Every selected live-context file has a matching SHA-256 copy in the shadow import."
Write-Host "No live OpenCode files were modified by this verification."

[pscustomobject]@{
    verified = $verified
    total_files = $expected.Count
    memory_files = $memoryFiles.Count
    project_files = $projectFiles.Count
    command_files = $commandFiles.Count
    skill_files = $skillFiles.Count
    canonical_project_files = $canonicalProjectFiles.Count
    failures = @($failures)
}
