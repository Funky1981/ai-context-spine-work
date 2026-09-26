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
    'scripts/New-ProjectSkill.ps1',
    'scripts/Test-Staleness.ps1',
    'scripts/Enable-Jev.ps1',
    'scripts/Invoke-Jev.ps1'
)

$missing = @()
foreach ($item in $required) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path)) {
        $missing += $item
    }
}

$configPath = Join-Path $Root 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

[pscustomobject]@{
    root = $Root
    profile = if ($null -ne $config) { $config.profile } else { $null }
    model_provider = if ($null -ne $config) { $config.model_provider } else { $null }
    external_ai_allowed = if ($null -ne $config) { $config.external_ai_allowed } else { $null }
    jev_enabled = if ($null -ne $config) { $config.jev.enabled } else { $null }
    missing_files = $missing
    healthy = ($missing.Count -eq 0)
}
