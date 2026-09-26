[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [switch]$ApprovedForWork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $Root 'config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing config: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if ($config.profile -eq 'work' -and -not $ApprovedForWork) {
    throw "Work profile is GLM-only by default. Jev remains blocked. Use -ApprovedForWork only after formal employer approval for this external service."
}

if ($config.profile -eq 'work' -and $ApprovedForWork) {
    Write-Warning "Changing the work profile to permit an external AI service. Confirm current employer approval before sending work content."
}

$config.external_ai_allowed = $true
$config.jev.enabled = $true
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

Write-Host "Jev adapter enabled in local config."
Write-Host "No API key was stored. Set JEV_API_KEY through an approved environment/secret mechanism before use."
