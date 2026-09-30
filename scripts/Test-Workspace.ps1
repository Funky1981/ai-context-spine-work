[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$required = @(
    'config.json',
    'AGENTS.md',
    'memory/MEMORY.md',
    'memory/lessons.md',
    'memory/preferences.md',
    'scripts/Register-Project.ps1',
    'scripts/Build-Index.ps1',
    'scripts/Search-Context.ps1',
    'scripts/Search-Memory.ps1',
    'scripts/New-ProjectSkill.ps1',
    'scripts/Test-Staleness.ps1',
    'scripts/Import-ExistingContext.ps1',
    'scripts/Test-ImportedContext.ps1',
    'scripts/Get-ContextMaintenance.ps1',
    'scripts/Save-Compaction.ps1',
    'scripts/Get-BranchSummaryContext.ps1',
    'scripts/Save-BranchSummary.ps1',
    'scripts/Enable-Jev.ps1',
    'scripts/Invoke-Jev.ps1'
)

$requiredDirs = @(
    'memory/projects',
    'context/compactions',
    'context/branches',
    'context/pending',
    'imports',
    'migrations'
)

$missing = @()
foreach ($item in $required) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path)) { $missing += $item }
}
foreach ($item in $requiredDirs) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { $missing += ($item + '/') }
}

$configPath = Join-Path $Root 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

$importCount = @(
    Get-ChildItem -LiteralPath (Join-Path $Root 'migrations') -Filter 'import-*.json' -File -ErrorAction SilentlyContinue
).Count

[pscustomobject]@{
    root = $Root
    profile = if ($null -ne $config) { $config.profile } else { $null }
    model_provider = if ($null -ne $config) { $config.model_provider } else { $null }
    external_ai_allowed = if ($null -ne $config) { $config.external_ai_allowed } else { $null }
    jev_enabled = if ($null -ne $config) { $config.jev.enabled } else { $null }
    compaction_enabled = if ($null -ne $config -and $null -ne $config.compaction) { $config.compaction.enabled } else { $false }
    preserve_raw = if ($null -ne $config -and $null -ne $config.compaction) { $config.compaction.preserve_raw } else { $false }
    legacy_import_manifests = $importCount
    missing_files = $missing
    healthy = ($missing.Count -eq 0)
}
