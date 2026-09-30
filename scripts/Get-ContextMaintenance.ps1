[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Project,
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [int]$TriggerEstimatedTokens = 0,
    [int]$KeepRecentEstimatedTokens = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

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

$configPath = Join-Path $Root 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

$compaction = Get-OptionalProperty -Object $config -Name 'compaction'
$enabled = Get-OptionalProperty -Object $compaction -Name 'enabled' -Default $true

if ($TriggerEstimatedTokens -le 0) {
    $configuredTrigger = Get-OptionalProperty -Object $compaction -Name 'trigger_estimated_tokens'
    $TriggerEstimatedTokens = if ($null -ne $configuredTrigger) { [int]$configuredTrigger } else { 60000 }
}

if ($KeepRecentEstimatedTokens -le 0) {
    $configuredKeep = Get-OptionalProperty -Object $compaction -Name 'keep_recent_estimated_tokens'
    $KeepRecentEstimatedTokens = if ($null -ne $configuredKeep) { [int]$configuredKeep } else { 20000 }
}

if ($TriggerEstimatedTokens -lt 1) { throw "TriggerEstimatedTokens must be greater than zero." }
if ($KeepRecentEstimatedTokens -lt 0) { throw "KeepRecentEstimatedTokens cannot be negative." }

if (-not [bool]$enabled) {
    [pscustomobject]@{
        project = $Project
        compaction_required = $false
        compaction_enabled = $false
        uncompacted_estimated_tokens = 0
        trigger_estimated_tokens = $TriggerEstimatedTokens
        keep_recent_estimated_tokens = $KeepRecentEstimatedTokens
        candidate_file_count = 0
        kept_recent_file_count = 0
        plan_path = $null
        raw_sources_preserved = $true
    }
    return
}

$sessionRoots = @(
    (Join-Path (Join-Path (Join-Path $Root 'memory/projects') $Project) 'sessions'),
    (Join-Path (Join-Path (Join-Path $Root 'memory/projects') $Project) 'handovers')
) | Select-Object -Unique

$manifestPath = Join-Path (Join-Path (Join-Path $Root 'context/compactions') $Project) 'manifest.jsonl'
$alreadyCompacted = @{}
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Get-Content -LiteralPath $manifestPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            try {
                $entry = $_ | ConvertFrom-Json
                $sources = Get-OptionalProperty -Object $entry -Name 'source_files' -Default @()
                foreach ($source in @($sources)) {
                    $path = Get-OptionalProperty -Object $source -Name 'path'
                    $sha = Get-OptionalProperty -Object $source -Name 'sha256'
                    if (-not [string]::IsNullOrWhiteSpace($path) -and -not [string]::IsNullOrWhiteSpace($sha)) {
                        $key = "$path|$sha"
                        $alreadyCompacted[$key] = $true
                    }
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
            $key = "$($_.FullName)|$hash"
            if (-not $alreadyCompacted.ContainsKey($key)) {
                $text = Get-Content -LiteralPath $_.FullName -Raw
                if ($null -eq $text) { $text = '' }
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
    compaction_enabled = $true
    uncompacted_estimated_tokens = $totalTokens
    trigger_estimated_tokens = $TriggerEstimatedTokens
    keep_recent_estimated_tokens = $KeepRecentEstimatedTokens
    candidate_file_count = $compact.Count
    kept_recent_file_count = $kept.Count
    plan_path = $planPath
    raw_sources_preserved = $true
}
