[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$State,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Question,
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [string]$Model = 'jev-latest'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $Root 'config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Missing context config: $configPath"
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if ($null -eq $config.PSObject.Properties['external_ai_allowed']) {
    throw "config.external_ai_allowed is missing."
}
if ($null -eq $config.PSObject.Properties['jev'] -or $null -eq $config.jev) {
    throw "config.jev is missing."
}
if ($null -eq $config.jev.PSObject.Properties['enabled']) {
    throw "config.jev.enabled is missing."
}
if ($null -eq $config.jev.PSObject.Properties['endpoint'] -or [string]::IsNullOrWhiteSpace([string]$config.jev.endpoint)) {
    throw "config.jev.endpoint is missing."
}

if (-not [bool]$config.external_ai_allowed -or -not [bool]$config.jev.enabled) {
    throw "Jev/external AI is disabled by this profile. Core context tooling does not require it."
}

if ([string]::IsNullOrWhiteSpace($env:JEV_API_KEY)) {
    throw "JEV_API_KEY is not set. Do not store the key in this repository or config.json."
}

$bodyObject = [ordered]@{
    state = $State
    model = $Model
    questions = @{
        decision = @{
            type = 'noul'
            instructions = $Question
        }
    }
}
$body = $bodyObject | ConvertTo-Json -Depth 8
$headers = @{ Authorization = "Bearer $env:JEV_API_KEY" }

$params = @{
    Method = 'Post'
    Uri = [string]$config.jev.endpoint
    Headers = $headers
    ContentType = 'application/json'
    Body = $body
}
Invoke-RestMethod @params
