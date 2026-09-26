[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Slug([string]$Value) {
    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

$resolved = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    throw "Project path is not a directory: $resolved"
}

$projectsDir = Join-Path $Root 'projects'
New-Item -ItemType Directory -Force -Path $projectsDir | Out-Null

$slug = Get-Slug $Name
$record = [ordered]@{
    name = $Name
    slug = $slug
    path = $resolved
    registered_at_utc = [DateTime]::UtcNow.ToString('o')
    status = 'active'
}

$recordPath = Join-Path $projectsDir ($slug + '.json')
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8

& (Join-Path $PSScriptRoot 'Build-Index.ps1') -Project $slug -Root $Root
& (Join-Path $PSScriptRoot 'New-ProjectSkill.ps1') -Project $slug -Root $Root

Write-Host "Registered project '$Name' as '$slug'."
Write-Host "Local record: $recordPath"
