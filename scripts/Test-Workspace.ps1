[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OptionalProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

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
    'scripts/Test-ScriptSyntax.ps1',
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
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing += $item }
}
foreach ($item in $requiredDirs) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { $missing += ($item + '/') }
}

$configPath = Join-Path $Root 'config.json'
$config = $null
$configError = $null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    }
    catch {
        $configError = $_.Exception.Message
    }
}

$profile = Get-OptionalProperty -Object $config -Name 'profile'
$modelProvider = Get-OptionalProperty -Object $config -Name 'model_provider'
$externalAiAllowed = Get-OptionalProperty -Object $config -Name 'external_ai_allowed'
$jev = Get-OptionalProperty -Object $config -Name 'jev'
$compaction = Get-OptionalProperty -Object $config -Name 'compaction'
$jevEnabled = Get-OptionalProperty -Object $jev -Name 'enabled'
$compactionEnabled = Get-OptionalProperty -Object $compaction -Name 'enabled'
$preserveRaw = Get-OptionalProperty -Object $compaction -Name 'preserve_raw'

$configWarnings = @()
if ($null -eq $config) { $configWarnings += 'config.json is missing or unreadable' }
if ([string]::IsNullOrWhiteSpace([string]$profile)) { $configWarnings += 'config.profile is missing' }
if ([string]::IsNullOrWhiteSpace([string]$modelProvider)) { $configWarnings += 'config.model_provider is missing' }
if ($null -eq $compaction) { $configWarnings += 'config.compaction is missing; rerun the current bootstrap with -Force to upgrade generated configuration' }
if ($null -eq $jev) { $configWarnings += 'config.jev is missing; rerun the current bootstrap with -Force to upgrade generated configuration' }

$migrationsPath = Join-Path $Root 'migrations'
$importCount = if (Test-Path -LiteralPath $migrationsPath -PathType Container) {
    @(Get-ChildItem -LiteralPath $migrationsPath -Filter 'import-*.json' -File -ErrorAction SilentlyContinue).Count
}
else {
    0
}

[pscustomobject]@{
    root = $Root
    profile = $profile
    model_provider = $modelProvider
    external_ai_allowed = $externalAiAllowed
    jev_enabled = $jevEnabled
    compaction_enabled = $compactionEnabled
    preserve_raw = $preserveRaw
    legacy_import_manifests = $importCount
    config_error = $configError
    config_warnings = @($configWarnings)
    missing_files = @($missing)
    healthy = ($missing.Count -eq 0 -and $null -eq $configError -and $configWarnings.Count -eq 0)
}
