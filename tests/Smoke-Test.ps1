[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Write-ValidSummary {
    param([Parameter(Mandatory = $true)][string]$Path)
@'
## Goal
Exercise Context Spine lifecycle.

## Constraints & Preferences
Keep raw context intact.

## Progress
### Done
Smoke-test setup completed.
### In Progress
None.
### Blocked
None.

## Key Decisions
Use local deterministic test data.

## Next Steps
Complete smoke test.

## Critical Context
This is synthetic CI data.
'@ | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$bootstrap = Join-Path $repoRoot 'bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap -PathType Leaf)) {
    throw "bootstrap.ps1 not found at repository root."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("context-spine-smoke-" + [Guid]::NewGuid().ToString('N'))
$ctxRoot = Join-Path $tempRoot 'context'
$legacyRoot = Join-Path $tempRoot 'legacy-opencode'
$projectRoot = Join-Path $tempRoot 'demo-project'
$directImportRoot = Join-Path $tempRoot 'direct-import-context'

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $legacyRoot 'memory/projects/demo') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $legacyRoot 'commands') | Out-Null

    ('# Legacy memory' + [Environment]::NewLine + 'legacy-decision-alpha') | Set-Content -LiteralPath (Join-Path $legacyRoot 'memory/MEMORY.md') -Encoding UTF8
    ('# Legacy lessons' + [Environment]::NewLine + 'legacy-lesson-beta') | Set-Content -LiteralPath (Join-Path $legacyRoot 'memory/lessons.md') -Encoding UTF8
    ('# Legacy preferences' + [Environment]::NewLine + 'legacy-preference-gamma') | Set-Content -LiteralPath (Join-Path $legacyRoot 'memory/preferences.md') -Encoding UTF8
    ('# Demo project memory' + [Environment]::NewLine + 'legacy-project-delta') | Set-Content -LiteralPath (Join-Path $legacyRoot 'memory/projects/demo/notes.md') -Encoding UTF8
    'legacy command' | Set-Content -LiteralPath (Join-Path $legacyRoot 'commands/legacy.md') -Encoding UTF8

    & $bootstrap -Profile work -Root $ctxRoot -ImportContextPath $legacyRoot -SkipLegacyImport

    $workspace = & (Join-Path $ctxRoot 'scripts/Test-Workspace.ps1') -Root $ctxRoot
    Assert-True -Condition ([bool]$workspace.healthy) -Message "Generated workspace should be healthy."
    Assert-True -Condition ($workspace.profile -eq 'work') -Message "Work profile should be retained."
    Assert-True -Condition (-not [bool]$workspace.external_ai_allowed) -Message "Work profile must keep external AI disabled."

    $syntax = & (Join-Path $ctxRoot 'scripts/Test-ScriptSyntax.ps1') -Root $ctxRoot
    Assert-True -Condition ([bool]$syntax.valid) -Message "All generated scripts should parse."

    $latestManifest = Get-ChildItem -LiteralPath (Join-Path $ctxRoot 'migrations') -Filter 'import-*.json' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    Assert-True -Condition ($null -ne $latestManifest) -Message "Migration manifest should exist."

    $verification = & (Join-Path $ctxRoot 'scripts/Test-ImportedContext.ps1') -ManifestPath $latestManifest.FullName
    Assert-True -Condition ([bool]$verification.verified) -Message "Imported context should verify."

    $globalMemory = Get-Content -LiteralPath (Join-Path $ctxRoot 'memory/MEMORY.md') -Raw
    Assert-True -Condition ($globalMemory.Contains('legacy-decision-alpha')) -Message "Legacy global memory should be integrated."
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $ctxRoot 'memory/projects/demo/notes.md') -PathType Leaf) -Message "Legacy project memory should be integrated."

    & (Join-Path $repoRoot 'scripts/Import-ExistingContext.ps1') -Source $legacyRoot -Root $directImportRoot | Out-Null
    $directManifest = Get-ChildItem -LiteralPath (Join-Path $directImportRoot 'migrations') -Filter 'import-*.json' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    $directVerification = & (Join-Path $repoRoot 'scripts/Test-ImportedContext.ps1') -ManifestPath $directManifest.FullName
    Assert-True -Condition ([bool]$directVerification.verified) -Message "Direct import should verify, including canonical-created files."

    New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
    & git -C $projectRoot init -b main | Out-Null
    & git -C $projectRoot config user.email 'context-spine-ci@example.invalid'
    & git -C $projectRoot config user.name 'Context Spine CI'

    "Write-Output 'needle-source-omega'" | Set-Content -LiteralPath (Join-Path $projectRoot 'app.ps1') -Encoding UTF8
    '# Demo' | Set-Content -LiteralPath (Join-Path $projectRoot 'README.md') -Encoding UTF8
    'EXAMPLE=true' | Set-Content -LiteralPath (Join-Path $projectRoot '.env.example') -Encoding UTF8
    & git -C $projectRoot add .
    & git -C $projectRoot commit -m 'initial' | Out-Null

    & (Join-Path $ctxRoot 'scripts/Register-Project.ps1') -Name 'Demo Project' -Path $projectRoot -Root $ctxRoot

    $search = @(& (Join-Path $ctxRoot 'scripts/Search-Context.ps1') -Project 'demo-project' -Pattern 'needle-source-omega' -Root $ctxRoot)
    Assert-True -Condition ($search.Count -gt 0) -Message "Source search should find indexed project content."

    $memorySearch = @(& (Join-Path $ctxRoot 'scripts/Search-Memory.ps1') -Pattern 'legacy-decision-alpha' -Root $ctxRoot)
    Assert-True -Condition ($memorySearch.Count -gt 0) -Message "Historical memory search should find migrated memory."

    $indexLines = @(Get-Content -LiteralPath (Join-Path $ctxRoot 'index/demo-project.files.jsonl'))
    Assert-True -Condition (($indexLines -join [Environment]::NewLine).Contains('.env.example')) -Message ".env.example should be indexed without indexing real .env secrets."

    $fresh = & (Join-Path $ctxRoot 'scripts/Test-Staleness.ps1') -Project 'demo-project' -Root $ctxRoot
    Assert-True -Condition (-not [bool]$fresh.stale) -Message "Freshly built index should not be stale."

    Add-Content -LiteralPath (Join-Path $projectRoot 'app.ps1') -Value "Write-Output 'changed'"
    $stale = & (Join-Path $ctxRoot 'scripts/Test-Staleness.ps1') -Project 'demo-project' -Root $ctxRoot
    Assert-True -Condition ([bool]$stale.stale) -Message "Modified project should be detected as stale."

    & (Join-Path $ctxRoot 'scripts/Build-Index.ps1') -Project 'demo-project' -Root $ctxRoot | Out-Null

    & git -C $projectRoot checkout -b feature/context-test | Out-Null
    'feature-line' | Set-Content -LiteralPath (Join-Path $projectRoot 'feature.txt') -Encoding UTF8
    & git -C $projectRoot add feature.txt
    & git -C $projectRoot commit -m 'feature commit' | Out-Null

    $branchContext = & (Join-Path $ctxRoot 'scripts/Get-BranchSummaryContext.ps1') -Project 'demo-project' -ToBranch 'main' -Root $ctxRoot
    Assert-True -Condition ($branchContext.from_branch -eq 'feature/context-test') -Message "Branch helper should identify current feature branch."
    Assert-True -Condition (@($branchContext.changed_files_leaving_branch).Count -gt 0) -Message "Branch helper should report changed files."

    $branchSummaryDraft = Join-Path $tempRoot 'branch-summary.md'
    Write-ValidSummary -Path $branchSummaryDraft
    $savedBranch = & (Join-Path $ctxRoot 'scripts/Save-BranchSummary.ps1') -Project 'demo-project' -FromBranch 'feature/context-test' -ToBranch 'main' -CommonAncestor $branchContext.common_ancestor -SummaryPath $branchSummaryDraft -Root $ctxRoot
    Assert-True -Condition (Test-Path -LiteralPath $savedBranch.summary_path -PathType Leaf) -Message "Branch summary should be persisted."

    $sessionsDir = Join-Path $ctxRoot 'memory/projects/demo-project/sessions'
    1..4 | ForEach-Object {
        ("session-$($_) " + ('x' * 400)) | Set-Content -LiteralPath (Join-Path $sessionsDir ("session-$_.md")) -Encoding UTF8
        Start-Sleep -Milliseconds 10
    }

    $maintenance = & (Join-Path $ctxRoot 'scripts/Get-ContextMaintenance.ps1') -Project 'demo-project' -Root $ctxRoot -TriggerEstimatedTokens 100 -KeepRecentEstimatedTokens 30
    Assert-True -Condition ([bool]$maintenance.compaction_required) -Message "Forced low threshold should require compaction."
    Assert-True -Condition (Test-Path -LiteralPath $maintenance.plan_path -PathType Leaf) -Message "Compaction plan should be created."

    $rawBefore = @(Get-ChildItem -LiteralPath $sessionsDir -File).Count
    $compactionDraft = Join-Path $tempRoot 'compaction-summary.md'
    Write-ValidSummary -Path $compactionDraft
    $savedCompaction = & (Join-Path $ctxRoot 'scripts/Save-Compaction.ps1') -Project 'demo-project' -PlanPath $maintenance.plan_path -SummaryPath $compactionDraft -Root $ctxRoot
    Assert-True -Condition (Test-Path -LiteralPath $savedCompaction.summary_path -PathType Leaf) -Message "Compaction summary should be persisted."
    $rawAfter = @(Get-ChildItem -LiteralPath $sessionsDir -File).Count
    Assert-True -Condition ($rawBefore -eq $rawAfter) -Message "Compaction must preserve all raw session files."

    $duplicateA = Join-Path $sessionsDir 'duplicate-a.md'
    $duplicateB = Join-Path $sessionsDir 'duplicate-b.md'
    ('duplicate-content ' + ('z' * 300)) | Set-Content -LiteralPath $duplicateA -Encoding UTF8
    Copy-Item -LiteralPath $duplicateA -Destination $duplicateB
    $duplicateMaintenance = & (Join-Path $ctxRoot 'scripts/Get-ContextMaintenance.ps1') -Project 'demo-project' -Root $ctxRoot -TriggerEstimatedTokens 1 -KeepRecentEstimatedTokens 0
    Assert-True -Condition ([bool]$duplicateMaintenance.compaction_required) -Message "Duplicate-session test should produce a compaction plan."
    $duplicatePlan = Get-Content -LiteralPath $duplicateMaintenance.plan_path -Raw | ConvertFrom-Json
    $plannedPaths = @($duplicatePlan.source_files | ForEach-Object { $_.path })
    Assert-True -Condition ($plannedPaths -contains $duplicateA) -Message "Duplicate-content file A should remain independently trackable."
    Assert-True -Condition ($plannedPaths -contains $duplicateB) -Message "Duplicate-content file B should remain independently trackable."

    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $legacyRoot 'memory/MEMORY.md') -Algorithm SHA256).Hash.ToLowerInvariant()
    & $bootstrap -Profile work -Root $ctxRoot -ImportContextPath $legacyRoot -SkipLegacyImport -Force

    $memoryAfterRerun = Get-Content -LiteralPath (Join-Path $ctxRoot 'memory/MEMORY.md') -Raw
    $marker = "<!-- context-spine-import sha256:$sourceHash -->"
    $markerCount = [regex]::Matches($memoryAfterRerun, [regex]::Escape($marker)).Count
    Assert-True -Condition ($markerCount -eq 1) -Message "Repeated installation must not duplicate unchanged imported global memory."

    $finalWorkspace = & (Join-Path $ctxRoot 'scripts/Test-Workspace.ps1') -Root $ctxRoot
    Assert-True -Condition ([bool]$finalWorkspace.healthy) -Message "Workspace should remain healthy after forced reinstall."

    Write-Host "CONTEXT SPINE SMOKE TEST: PASSED"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
