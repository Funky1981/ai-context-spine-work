[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Project,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$FromBranch,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ToBranch,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SummaryPath,
    [string]$CommonAncestor,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)) {
    throw "Branch summary not found: $SummaryPath"
}

$summary = Get-Content -LiteralPath $SummaryPath -Raw
$requiredHeadings = @(
    '## Goal',
    '## Constraints & Preferences',
    '## Progress',
    '## Key Decisions',
    '## Next Steps',
    '## Critical Context'
)
foreach ($heading in $requiredHeadings) {
    if (-not $summary.Contains($heading)) {
        throw "Summary is missing required heading: $heading"
    }
}

$outDir = Join-Path (Join-Path $Root 'context/branches') $Project
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$hash = (Get-FileHash -LiteralPath $SummaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
$safeFrom = ($FromBranch -replace '[^A-Za-z0-9._-]+','-')
$safeTo = ($ToBranch -replace '[^A-Za-z0-9._-]+','-')
$outPath = Join-Path $outDir ("$stamp-$safeFrom-to-$safeTo-$($hash.Substring(0,8)).md")
Copy-Item -LiteralPath $SummaryPath -Destination $outPath

$entry = [ordered]@{
    schema = 'context-spine-branch-summary-v1'
    project = $Project
    created_at_utc = [DateTime]::UtcNow.ToString('o')
    from_branch = $FromBranch
    to_branch = $ToBranch
    common_ancestor = $CommonAncestor
    summary_path = $outPath
    summary_sha256 = $hash
    raw_sources_preserved = $true
}
$manifestPath = Join-Path $outDir 'manifest.jsonl'
($entry | ConvertTo-Json -Depth 6 -Compress) | Add-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Branch summary recorded: $outPath"
Write-Host "Git history, source files and raw session memory were not modified."
[pscustomobject]@{
    project = $Project
    summary_path = $outPath
    manifest = $manifestPath
    raw_sources_preserved = $true
}
