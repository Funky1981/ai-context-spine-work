[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$ToBranch,
    [string]$FromBranch,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
if (-not (Test-Path -LiteralPath $recordPath)) {
    throw "Unknown project '$Project'. Register it first."
}
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$repo = $record.path

$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git) {
    throw "git is required for branch summary context."
}

if ([string]::IsNullOrWhiteSpace($FromBranch)) {
    $FromBranch = (& $git.Source -C $repo branch --show-current).Trim()
}
if ([string]::IsNullOrWhiteSpace($FromBranch)) {
    throw "Could not determine the current Git branch."
}

& $git.Source -C $repo rev-parse --verify $FromBranch *> $null
if ($LASTEXITCODE -ne 0) { throw "Unknown from-branch '$FromBranch'." }
& $git.Source -C $repo rev-parse --verify $ToBranch *> $null
if ($LASTEXITCODE -ne 0) { throw "Unknown target branch '$ToBranch'." }

$mergeBase = (& $git.Source -C $repo merge-base $FromBranch $ToBranch).Trim()
$commits = @(& $git.Source -C $repo log --format='%H%x09%s' "$mergeBase..$FromBranch")
$changedFiles = @(& $git.Source -C $repo diff --name-only "$mergeBase..$FromBranch")

$sessionRoot = Join-Path (Join-Path (Join-Path $Root 'memory/projects') $Project) 'sessions'
$recentSessions = @()
if (Test-Path -LiteralPath $sessionRoot -PathType Container) {
    $recentSessions = @(
        Get-ChildItem -LiteralPath $sessionRoot -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 5 |
            ForEach-Object { $_.FullName }
    )
}

[pscustomobject]@{
    schema = 'context-spine-branch-context-v1'
    project = $Project
    repository = $repo
    from_branch = $FromBranch
    to_branch = $ToBranch
    common_ancestor = $mergeBase
    commits_leaving_branch = $commits
    changed_files_leaving_branch = $changedFiles
    recent_session_files = $recentSessions
    raw_sources_preserved = $true
}
