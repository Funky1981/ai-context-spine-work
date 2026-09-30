[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Project,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PlanPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SummaryPath,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
    throw "Compaction plan not found: $PlanPath"
}
if (-not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)) {
    throw "Compaction summary not found: $SummaryPath"
}

$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
foreach ($requiredProperty in @('project','source_files','kept_recent_files')) {
    if ($null -eq $plan.PSObject.Properties[$requiredProperty]) {
        throw "Compaction plan is missing required property '$requiredProperty'."
    }
}
if ($plan.project -ne $Project) {
    throw "Plan project '$($plan.project)' does not match requested project '$Project'."
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

foreach ($source in @($plan.source_files)) {
    if (-not (Test-Path -LiteralPath $source.path -PathType Leaf)) {
        throw "Raw source disappeared before compaction could be recorded: $($source.path)"
    }
    $currentHash = (Get-FileHash -LiteralPath $source.path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($currentHash -ne $source.sha256) {
        throw "Raw source changed since the plan was generated: $($source.path)"
    }
}

$outDir = Join-Path (Join-Path $Root 'context/compactions') $Project
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$summaryHash = (Get-FileHash -LiteralPath $SummaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
$outPath = Join-Path $outDir ("$stamp-$($summaryHash.Substring(0,8)).md")
Copy-Item -LiteralPath $SummaryPath -Destination $outPath

$planArchive = Join-Path $outDir ("$stamp-$($summaryHash.Substring(0,8)).plan.json")
Copy-Item -LiteralPath $PlanPath -Destination $planArchive

$entry = [ordered]@{
    schema = 'context-spine-compaction-v1'
    project = $Project
    created_at_utc = [DateTime]::UtcNow.ToString('o')
    summary_path = $outPath
    summary_sha256 = $summaryHash
    source_files = @($plan.source_files)
    kept_recent_files = @($plan.kept_recent_files)
    raw_sources_preserved = $true
    plan_archive = $planArchive
}

$manifestPath = Join-Path $outDir 'manifest.jsonl'
($entry | ConvertTo-Json -Depth 8 -Compress) | Add-Content -LiteralPath $manifestPath -Encoding UTF8

Remove-Item -LiteralPath $PlanPath -Force

Write-Host "Compaction recorded: $outPath"
Write-Host "Raw session/handover files were preserved and were not modified."
[pscustomobject]@{
    project = $Project
    summary_path = $outPath
    manifest = $manifestPath
    raw_sources_preserved = $true
}
