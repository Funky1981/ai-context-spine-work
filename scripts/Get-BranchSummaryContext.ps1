[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Project,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ToBranch,
    [string]$FromBranch,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
    throw "Unknown project '$Project'. Register it first."
}
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$repo = [string]$record.path

if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
    throw "Registered repository path no longer exists: $repo"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git) {
    throw "git is required for branch summary context."
}

$insideWorkTree = @(& $git.Source -C $repo rev-parse --is-inside-work-tree 2>$null)
if ($LASTEXITCODE -ne 0 -or ($insideWorkTree -join '').Trim() -ne 'true') {
    throw "Registered project is not a Git working tree: $repo"
}

if ([string]::IsNullOrWhiteSpace($FromBranch)) {
    $fromOutput = @(& $git.Source -C $repo branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Could not determine the current Git branch." }
    $FromBranch = ($fromOutput -join [Environment]::NewLine).Trim()
}
if ([string]::IsNullOrWhiteSpace($FromBranch)) {
    throw "Could not determine the current Git branch. Detached HEAD is not supported by this helper."
}

& $git.Source -C $repo rev-parse --verify "$FromBranch^{commit}" *> $null
if ($LASTEXITCODE -ne 0) { throw "Unknown from-branch '$FromBranch'." }

& $git.Source -C $repo rev-parse --verify "$ToBranch^{commit}" *> $null
if ($LASTEXITCODE -ne 0) { throw "Unknown target branch '$ToBranch'." }

$mergeOutput = @(& $git.Source -C $repo merge-base $FromBranch $ToBranch 2>$null)
if ($LASTEXITCODE -ne 0) {
    throw "Could not determine a common ancestor between '$FromBranch' and '$ToBranch'."
}
$mergeBase = ($mergeOutput -join [Environment]::NewLine).Trim()
if ([string]::IsNullOrWhiteSpace($mergeBase)) {
    throw "No common ancestor was returned for '$FromBranch' and '$ToBranch'."
}

$commits = @(& $git.Source -C $repo log --format='%H%x09%s' "$mergeBase..$FromBranch")
if ($LASTEXITCODE -ne 0) { throw "Could not read commits for '$FromBranch'." }

$changedFiles = @(& $git.Source -C $repo diff --name-only "$mergeBase..$FromBranch")
if ($LASTEXITCODE -ne 0) { throw "Could not read changed files for '$FromBranch'." }

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
