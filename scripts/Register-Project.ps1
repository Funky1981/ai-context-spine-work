[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Path,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Slug([string]$Value) {
    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Project path is not a directory: $Path"
}
$resolved = (Resolve-Path -LiteralPath $Path).Path

$projectsDir = Join-Path $Root 'projects'
New-Item -ItemType Directory -Force -Path $projectsDir | Out-Null

$slug = Get-Slug $Name
if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "Project name '$Name' does not produce a usable slug. Include at least one letter or number."
}

$recordPath = Join-Path $projectsDir ($slug + '.json')
$registeredAt = [DateTime]::UtcNow.ToString('o')

if (Test-Path -LiteralPath $recordPath -PathType Leaf) {
    $existing = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    $existingPath = [string]$existing.path
    if (-not [string]::Equals(
        [System.IO.Path]::GetFullPath($existingPath).TrimEnd([char[]]"\/"),
        [System.IO.Path]::GetFullPath($resolved).TrimEnd([char[]]"\/"),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Project slug '$slug' is already registered to '$existingPath'. Choose a distinct project name instead of overwriting it."
    }
    if ($existing.PSObject.Properties['registered_at_utc']) {
        $registeredAt = [string]$existing.registered_at_utc
    }
}

$record = [ordered]@{
    name = $Name
    slug = $slug
    path = $resolved
    registered_at_utc = $registeredAt
    refreshed_at_utc = [DateTime]::UtcNow.ToString('o')
    status = 'active'
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8

$projectMemoryRoot = Join-Path (Join-Path $Root 'memory/projects') $slug
New-Item -ItemType Directory -Force -Path $projectMemoryRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectMemoryRoot 'sessions') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectMemoryRoot 'handovers') | Out-Null

& (Join-Path $PSScriptRoot 'Build-Index.ps1') -Project $slug -Root $Root
& (Join-Path $PSScriptRoot 'New-ProjectSkill.ps1') -Project $slug -Root $Root

Write-Host "Registered project '$Name' as '$slug'."
Write-Host "Local record: $recordPath"
