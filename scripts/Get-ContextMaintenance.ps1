[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [int]$TriggerEstimatedTokens = 0,
    [int]$KeepRecentEstimatedTokens = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$configPath = Join-Path $Root 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

if ($TriggerEstimatedTokens -le 0) {
    if ($null -ne $config -and $null -ne $config.compaction -and $config.compaction.trigger_estimated_tokens) {
        $TriggerEstimatedTokens = [int]$config.compaction.trigger_estimated_tokens
    }
    else {
        $TriggerEstimatedTokens = 60000
    }
}

if ($KeepRecentEstimatedTokens -le 0) {
    if ($null -ne $config -and $null -ne $config.compaction -and $config.compaction.keep_recent_estimated_tokens) {
        $KeepRecentEstimatedTokens = [int]$config.compaction.keep_recent_estimated_tokens
    }
    else {
        $KeepRecentEstimatedTokens = 20000
    }
}

$sessionRoots = @(
    (Join-Path (Join-Path (Join-Path $Root 'memory/projects') $Project) 'sessions'),
    (Join-Path (Join-Path (Join-Path $Root 'memory/projects') $Project) 'handovers')
) | Select-Object -Unique

$manifestPath = Join-Path (Join-Path (Join-Path $Root 'context/compactions') $Project) 'manifest.jsonl'
$alreadyCompacted = @{}
if (Test-Path -LiteralPath $manifestPath) {
    Get-Content -LiteralPath $manifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        try {
            $entry = $_ | ConvertFrom-Json
            foreach ($source in @($entry.source_files)) {
                if ($null -ne $source.sha256) { $alreadyCompacted[$source.sha256] = $true }
            }
        }
        catch {
            Write-Warning "Ignoring unreadable compaction manifest line: $manifestPath"
        }
    }
}

$items = New-Object System.Collections.Generic.List[object]
foreach ($sessionRoot in $sessionRoots) {
    if (-not (Test-Path -LiteralPath $sessionRoot -PathType Container)) { continue }

    Get-ChildItem -LiteralPath $sessionRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.md','.txt','.json') } |
        ForEach-Object {
            $hash = Get-FileSha256 $_.FullName
            if (-not $alreadyCompacted.ContainsKey($hash)) {
                $text = Get-Content -LiteralPath $_.FullName -Raw
                $tokens = [Math]::Ceiling($text.Length / 4.0)
                $items.Add([pscustomobject]@{
                    path = $_.FullName
                    modified_utc = $_.LastWriteTimeUtc
                    sha256 = $hash
                    estimated_tokens = [int]$tokens
                })
            }
        }
}

$ordered = @($items | Sort-Object modified_utc)
$sum = ($ordered | Measure-Object -Property estimated_tokens -Sum).Sum
$totalTokens = if ($null -eq $sum) { 0 } else { [int]$sum }

$compact = New-Object System.Collections.Generic.List[object]
$kept = New-Object System.Collections.Generic.List[object]
$keptTokens = 0

foreach ($item in @($ordered | Sort-Object modified_utc -Descending)) {
    if (($keptTokens + $item.estimated_tokens) -le $KeepRecentEstimatedTokens -or $kept.Count -eq 0) {
        $kept.Add($item)
        $keptTokens += $item.estimated_tokens
    }
    else {
        $compact.Add($item)
    }
}

$compactionRequired = $totalTokens -gt $TriggerEstimatedTokens -and $compact.Count -gt 0
$planPath = $null

if ($compactionRequired) {
    $pendingDir = Join-Path $Root 'context/pending'
    New-Item -ItemType Directory -Force -Path $pendingDir | Out-Null
    $planPath = Join-Path $pendingDir ($Project + '-compaction.json')

    $plan = [ordered]@{
        schema = 'context-spine-compaction-plan-v1'
        project = $Project
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        trigger_estimated_tokens = $TriggerEstimatedTokens
        keep_recent_estimated_tokens = $KeepRecentEstimatedTokens
        uncompacted_estimated_tokens = $totalTokens
        raw_sources_preserved = $true
        source_files = @($compact | Sort-Object modified_utc)
        kept_recent_files = @($kept | Sort-Object modified_utc)
    }
    $plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $planPath -Encoding UTF8
}

[pscustomobject]@{
    project = $Project
    compaction_required = $compactionRequired
    uncompacted_estimated_tokens = $totalTokens
    trigger_estimated_tokens = $TriggerEstimatedTokens
    keep_recent_estimated_tokens = $KeepRecentEstimatedTokens
    candidate_file_count = $compact.Count
    kept_recent_file_count = $kept.Count
    plan_path = $planPath
    raw_sources_preserved = $true
}
