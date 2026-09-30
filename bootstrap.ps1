[CmdletBinding()]
param(
    [ValidateSet('home','work')][string]$Profile = 'home',
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [switch]$InstallOpenCode,
    [string[]]$ImportContextPath = @(),
    [switch]$SkipLegacyImport,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ManagedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$NeverOverwrite
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    if (Test-Path -LiteralPath $Path) {
        if ($NeverOverwrite -or -not $Force) {
            Write-Host "SKIP existing: $Path"
            return
        }
    }

    $Content | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Host "WRITE: $Path"
}

$dirs = @(
    $Root,
    (Join-Path $Root 'memory'),
    (Join-Path $Root 'memory/projects'),
    (Join-Path $Root 'projects'),
    (Join-Path $Root 'skills'),
    (Join-Path $Root 'skills/projects'),
    (Join-Path $Root 'index'),
    (Join-Path $Root 'context'),
    (Join-Path $Root 'context/compactions'),
    (Join-Path $Root 'context/branches'),
    (Join-Path $Root 'context/pending'),
    (Join-Path $Root 'imports'),
    (Join-Path $Root 'migrations'),
    (Join-Path $Root 'commands'),
    (Join-Path $Root 'scripts')
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

if ($Profile -eq 'work') {
    $config = @'
{
  "profile": "work",
  "model_provider": "glm",
  "external_ai_allowed": false,
  "telemetry": false,
  "auto_install": false,
  "index": {
    "mode": "local-lexical",
    "store_content": false
  },
  "migration": {
    "auto_import_legacy_opencode": true,
    "preserve_sources": true
  },
  "compaction": {
    "enabled": true,
    "trigger_estimated_tokens": 60000,
    "keep_recent_estimated_tokens": 20000,
    "preserve_raw": true,
    "summarizer": "active-agent"
  },
  "branch_summary": {
    "enabled": true,
    "preserve_raw": true,
    "summarizer": "active-agent"
  },
  "jev": {
    "enabled": false,
    "model": "jev-latest",
    "endpoint": "https://api.typesafe.ai/v1/systemone"
  }
}
'@
}
else {
    $config = @'
{
  "profile": "home",
  "model_provider": "configured-in-coding-agent",
  "external_ai_allowed": true,
  "telemetry": false,
  "auto_install": false,
  "index": {
    "mode": "local-lexical",
    "store_content": false
  },
  "migration": {
    "auto_import_legacy_opencode": true,
    "preserve_sources": true
  },
  "compaction": {
    "enabled": true,
    "trigger_estimated_tokens": 60000,
    "keep_recent_estimated_tokens": 20000,
    "preserve_raw": true,
    "summarizer": "active-agent"
  },
  "branch_summary": {
    "enabled": true,
    "preserve_raw": true,
    "summarizer": "active-agent"
  },
  "jev": {
    "enabled": false,
    "model": "jev-latest",
    "endpoint": "https://api.typesafe.ai/v1/systemone"
  }
}
'@
}

$globalAgents = @'
# AI Context Spine - global coding guidance

Use the current repository as the authoritative source for implementation truth.

## Context order

When useful for the task:
1. Read the project's own AGENTS.md and canonical documentation.
2. Use the registered project skill as an orientation map.
3. Search actual source files for implementation details.
4. Search Context Spine memory, compaction summaries and branch summaries for prior decisions/lessons.
5. Treat persistent memory as historical context, never as proof of current code state.
6. If generated context conflicts with the repository, the repository wins.

## Context lifecycle

- Raw session and handover files are historical evidence. Never delete, truncate or rewrite them during compaction.
- Compaction summaries are derived context and must remain traceable to the SHA-256 hashes of their raw sources.
- After creating a durable handover, run Get-ContextMaintenance.ps1 for the current project.
- If compaction is required, compact the planned older sessions while keeping recent context intact.
- Before leaving an unfinished Git branch, create a branch summary so abandoned or paused work remains discoverable.
- Imported legacy memory is additive. Never delete or modify the legacy source location during import.
- Use Search-Memory.ps1 for historical retrieval before loading large volumes of old session files.

## Safety

- Never store credentials, tokens, secrets or sensitive source excerpts in global memory.
- Never send repository content to an external provider unless the active profile explicitly permits it and the provider is approved for that environment.
- Work profile is GLM-only by default.
- Jev is optional and for narrow typed decisions only; it is not required for coding.
- Do not bypass security, proxy, endpoint, download or policy controls.

## Change discipline

- Inspect before editing.
- Keep changes scoped.
- Run the repository's relevant tests/verification.
- Call out uncertainty rather than inventing project facts.
- Rebuild local project index/skill after material structural changes.
'@

$memory = @'
# Global Coding Memory

Keep this small.

Store only durable cross-project information that materially improves future coding sessions.

Do not store:
- credentials or secrets
- employer/customer data
- large source-code excerpts
- temporary task state

Project-specific decisions belong under memory/projects/.
'@

$lessons = @'
# Lessons

Record durable lessons from coding/debugging work.

Suggested format:

## YYYY-MM-DD - short lesson
- Context:
- Lesson:
- Why it matters:
- Applies to:
- Source/project reference:
'@

$preferences = @'
# Coding Preferences

Store durable workflow preferences only.

Examples:
- preferred explanation depth
- testing expectations
- architecture/review habits
- preferred tooling

Do not store secrets or project source.
'@

$projectTemplate = @'
# Project Memory - PROJECT_NAME

## Purpose

## Architecture decisions

## Conventions

## Known traps

## Durable lessons

## Current canonical docs

Repository source remains authoritative. Remove or mark stale entries when the codebase changes.
'@

$commandRemember = @'
---
description: Record a durable coding decision or lesson in local context memory
---

Record the durable information in $ARGUMENTS into the appropriate local AI Context Spine memory file.

Rules:
- Do not store credentials, secrets, tokens, customer/company data, or large source-code excerpts.
- Prefer a concise decision/lesson plus rationale and project name.
- Do not treat memory as current repository truth.
- If the information is temporary task state, put it in a handover instead of long-term memory.
'@

$commandHandover = @'
---
description: Create a durable handover and run Context Spine maintenance
---

Create a new timestamped handover for the current registered project.

Store the raw handover as a new Markdown file beneath:

memory/projects/<project>/sessions/

Do not overwrite a previous session/handover file.

Capture:
- project and current objective
- completed work
- files/components materially changed
- tests/verification run and results
- important decisions and rationale
- unresolved risks/questions
- exact next action

Do not include secrets. Prefer repository references over copying large source blocks.

After saving the raw handover:
1. Run ~/.agent-context/scripts/Get-ContextMaintenance.ps1 -Project "<project>".
2. If compaction_required is true, execute the ctx-compact workflow automatically.
3. Never delete or rewrite the raw handover/session files after compaction.
'@

$commandMemoryStatus = @'
---
description: Summarize relevant local memory, lifecycle state and stale or conflicting items
---

Review the local AI Context Spine memory relevant to the current project.

Use Search-Memory.ps1 for historical retrieval and Test-Staleness.ps1 for repository index state.

Also run Get-ContextMaintenance.ps1 for the current project and report whether compaction is currently required.

Report:
- durable project decisions
- useful lessons
- unresolved handovers
- recent compaction summaries
- relevant branch summaries
- compaction-required status
- anything that appears stale or conflicts with current repository truth
- legacy import manifests when migration provenance matters

Repository source and committed project instructions override memory. Raw imported/session history must remain preserved.
'@

$commandProjectSkill = @'
---
description: Refresh the compact project coding skill from current repository truth
---

Refresh the current project's local project skill.

Use the repository itself as authority. Capture only high-value orientation:
- architecture boundaries
- important directories/modules
- build/test/lint commands
- API/database conventions
- security/safety constraints
- known project-specific traps
- canonical documentation pointers

Do not copy large source sections. Preserve exact source-file references for claims. If the deterministic fingerprint is stale, rebuild it first.
'@

$commandSearch = @'
---
description: Search registered project source for task-relevant context
---

Use the local Search-Context.ps1 helper for $ARGUMENTS when the project is registered. Read the actual matched source files before drawing implementation conclusions.

Do not infer current behavior from memory or a generated project skill when the source can answer it.
'@

$commandCompact = @'
---
description: Compact older project session context without deleting the original history
---

Compact Context Spine history for the current registered project.

1. Determine the current project slug from the Context Spine project registry.
2. Run ~/.agent-context/scripts/Get-ContextMaintenance.ps1 -Project "<slug>".
3. If compaction_required is false, report that no compaction is required and stop.
4. If it is true, read only the source files listed in the generated plan plus any durable project memory needed to understand them.
5. Produce a concise structured summary using exactly these headings:
   - ## Goal
   - ## Constraints & Preferences
   - ## Progress
     - ### Done
     - ### In Progress
     - ### Blocked
   - ## Key Decisions
   - ## Next Steps
   - ## Critical Context
6. Preserve exact file paths, function/component names, error messages, decisions and unresolved work. Do not invent missing context.
7. Write the draft summary to a temporary local Markdown file.
8. Persist it with Save-Compaction.ps1 -Project "<slug>" -PlanPath "<plan>" -SummaryPath "<draft>".
9. Delete only the temporary draft after the save succeeds.

Hard rule: compaction is additive. Never delete, rewrite, truncate, move or replace the raw session/handover files that were summarized.
'@

$commandBranchSummary = @'
---
description: Preserve context when forking a coding-session path or leaving unfinished Git branch work
---

Create a Context Spine branch/fork summary before leaving an unfinished line of work. The target or new branch/fork label is in $ARGUMENTS.

Use the active conversation/session as the primary evidence.

If this is also a Git branch switch:
1. Determine the current registered project slug and current Git branch.
2. Run ~/.agent-context/scripts/Get-BranchSummaryContext.ps1 -Project "<slug>" -ToBranch "<target-git-branch>".
3. Use the returned merge base, commits, changed files and recent session files as additional evidence.

If this is an OpenCode/session fork or simply an alternative approach rather than a Git branch:
1. Record the current session/fork identifier when available.
2. Use a clear human-readable from/to label for the path being left and the path being entered.
3. Preserve the decisions, experiments and unresolved work from the path being left.

Produce a concise structured summary using exactly these headings:
- ## Goal
- ## Constraints & Preferences
- ## Progress
  - ### Done
  - ### In Progress
  - ### Blocked
- ## Key Decisions
- ## Next Steps
- ## Critical Context

Preserve exact file paths, function/component names, errors, important evidence and materially read/modified files. Do not invent missing context.

Write the draft summary to a temporary local Markdown file, then persist it with Save-BranchSummary.ps1 using the from/to branch or fork labels. Delete only the temporary draft after the save succeeds.

Hard rule: branch/fork summarization is additive. Never delete or rewrite Git history, repository files, session history or raw Context Spine memory.
'@

$registerProject = @'
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
'@

$buildIndex = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StringHash([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
if (-not (Test-Path -LiteralPath $recordPath)) {
    throw "Unknown project '$Project'. Register it first."
}

$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$projectPath = [string]$record.path
if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
    throw "Registered repository path no longer exists: $projectPath"
}

$indexDir = Join-Path $Root 'index'
New-Item -ItemType Directory -Force -Path $indexDir | Out-Null

$allowedExtensions = @(
    '.go','.mod','.sum','.cs','.csproj','.sln','.props','.targets',
    '.ts','.tsx','.js','.jsx','.json','.jsonc','.md','.txt',
    '.yaml','.yml','.toml','.sql','.ps1','.psm1','.py','.sh',
    '.html','.css','.scss','.xml','.ini','.conf','.env.example'
)
$allowedNames = @('Dockerfile','Makefile','README','AGENTS.md','.editorconfig','.gitignore','.env.example')
$skipPattern = '[\\/](\.git|node_modules|bin|obj|dist|build|coverage|vendor|\.venv|venv|\.next|target)[\\/]'

$entries = New-Object System.Collections.Generic.List[object]
$aggregate = New-Object System.Text.StringBuilder

Get-ChildItem -LiteralPath $projectPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $skipPattern -and (
            $allowedExtensions -contains $_.Extension.ToLowerInvariant() -or
            $allowedNames -contains $_.Name
        )
    } |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($projectPath.Length).TrimStart([char[]]"\/")
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $entry = [ordered]@{
            path = $relative
            extension = $_.Extension.ToLowerInvariant()
            bytes = $_.Length
            modified_utc = $_.LastWriteTimeUtc.ToString('o')
            sha256 = $hash
        }
        $entries.Add($entry)
        [void]$aggregate.Append($relative).Append('|').Append($hash).Append([Environment]::NewLine)
    }

$indexPath = Join-Path $indexDir ($Project + '.files.jsonl')
$entries | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -LiteralPath $indexPath -Encoding UTF8

$state = [ordered]@{
    project = $Project
    project_path = $projectPath
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    file_count = $entries.Count
    aggregate_sha256 = Get-StringHash $aggregate.ToString()
}
$statePath = Join-Path $indexDir ($Project + '.state.json')
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8

Write-Host "Indexed $($entries.Count) text/code files for '$Project'."
Write-Host "Index stores metadata/hashes only; source content remains in the repository."
'@

$searchContext = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Project,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Pattern,
    [ValidateRange(1,10000)][int]$Limit = 40,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
if (-not (Test-Path -LiteralPath $recordPath)) {
    throw "Unknown project '$Project'. Register it first."
}
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$projectPath = $record.path

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -ne $rg) {
    $args = @(
        '--line-number','--color','never',
        '--glob','!.git/**',
        '--glob','!node_modules/**',
        '--glob','!bin/**',
        '--glob','!obj/**',
        '--glob','!dist/**',
        '--glob','!build/**',
        '--glob','!coverage/**',
        '--glob','!vendor/**',
        '--glob','!.venv/**',
        '--fixed-strings','--',$Pattern,$projectPath
    )
    & $rg.Source @args 2>$null | Select-Object -First $Limit
    return
}

$skipPattern = '[\\/](\.git|node_modules|bin|obj|dist|build|coverage|vendor|\.venv|venv|\.next|target)[\\/]'
$allowedExtensions = @(
    '.go','.mod','.sum','.cs','.csproj','.sln','.props','.targets',
    '.ts','.tsx','.js','.jsx','.json','.jsonc','.md','.txt',
    '.yaml','.yml','.toml','.sql','.ps1','.psm1','.py','.sh',
    '.html','.css','.scss','.xml','.ini','.conf'
)

$matches = Get-ChildItem -LiteralPath $projectPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $skipPattern -and $allowedExtensions -contains $_.Extension.ToLowerInvariant() } |
    Select-String -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue |
    Select-Object -First $Limit

foreach ($match in $matches) {
    $relative = $match.Path.Substring($projectPath.Length).TrimStart([char[]]"\/")
    "$($relative):$($match.LineNumber): $($match.Line.Trim())"
}
'@

$newProjectSkill = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
if (-not (Test-Path -LiteralPath $recordPath)) {
    throw "Unknown project '$Project'. Register it first."
}

$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $record.path -PathType Container)) {
    throw "Registered repository path no longer exists: $($record.path)"
}
$statePath = Join-Path (Join-Path $Root 'index') ($Project + '.state.json')
$indexPath = Join-Path (Join-Path $Root 'index') ($Project + '.files.jsonl')

if (-not (Test-Path -LiteralPath $statePath) -or -not (Test-Path -LiteralPath $indexPath)) {
    & (Join-Path $PSScriptRoot 'Build-Index.ps1') -Project $Project -Root $Root
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$entries = @(Get-Content -LiteralPath $indexPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })

$topExtensions = $entries |
    Group-Object extension |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        $label = if ([string]::IsNullOrWhiteSpace($_.Name)) { '[no extension]' } else { $_.Name }
        "- $label : $($_.Count) files"
    }

$canonicalNames = @(
    'AGENTS.md','README.md','README','go.mod','package.json',
    '*.sln','*.csproj','pyproject.toml','Cargo.toml','Dockerfile',
    'docker-compose.yml','docker-compose.yaml'
)

$canonical = New-Object System.Collections.Generic.List[string]
foreach ($name in $canonicalNames) {
    Get-ChildItem -LiteralPath $record.path -Filter $name -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $relative = $_.FullName.Substring($record.path.Length).TrimStart([char[]]"\/")
            if (-not $canonical.Contains($relative)) { $canonical.Add($relative) }
        }
}

$skillDir = Join-Path (Join-Path $Root 'skills') (Join-Path 'projects' $Project)
New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
$skillPath = Join-Path $skillDir 'SKILL.md'

$extensionText = if ($topExtensions) { $topExtensions -join [Environment]::NewLine } else { '- No indexed source files detected.' }
$canonicalText = if ($canonical.Count -gt 0) {
    ($canonical | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
    '- None detected at repository root. Inspect the repository before making assumptions.'
}

$content = @"
---
name: project-$Project
description: Local coding orientation for $($record.name). Source repository remains authoritative.
---

# $($record.name) project skill

## Authority

Repository: $($record.path)

This generated skill is an orientation/index layer, not repository truth. If it conflicts with source code, tests, committed instructions or canonical project documentation, use the repository source.

## Snapshot

- Generated: $([DateTime]::UtcNow.ToString('o'))
- Indexed files: $($state.file_count)
- Source fingerprint: $($state.aggregate_sha256)

## Dominant file types

$extensionText

## Canonical entry points detected

$canonicalText

## Working rules

1. Read repository AGENTS.md and canonical docs before changing architecture.
2. Search actual source with Search-Context.ps1; do not rely on this generated summary for implementation details.
3. Preserve existing tests and conventions unless the task explicitly changes them.
4. Treat generated memory/skills as context, not evidence that code currently behaves a certain way.
5. Rebuild the index/skill after structural changes.

## Useful commands

Search:
~/.agent-context/scripts/Search-Context.ps1 -Project "$Project" -Pattern "<term>"

Check staleness:
~/.agent-context/scripts/Test-Staleness.ps1 -Project "$Project"

Rebuild:
~/.agent-context/scripts/Build-Index.ps1 -Project "$Project"
~/.agent-context/scripts/New-ProjectSkill.ps1 -Project "$Project"
"@

$content | Set-Content -LiteralPath $skillPath -Encoding UTF8
Write-Host "Generated project skill: $skillPath"
'@

$testStaleness = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StringHash([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$recordPath = Join-Path (Join-Path $Root 'projects') ($Project + '.json')
$statePath = Join-Path (Join-Path $Root 'index') ($Project + '.state.json')
if (-not (Test-Path -LiteralPath $recordPath) -or -not (Test-Path -LiteralPath $statePath)) {
    throw "Project '$Project' does not have a complete registry/index."
}

$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $record.path -PathType Container)) {
    throw "Registered repository path no longer exists: $($record.path)"
}
$oldState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json

$allowedExtensions = @(
    '.go','.mod','.sum','.cs','.csproj','.sln','.props','.targets',
    '.ts','.tsx','.js','.jsx','.json','.jsonc','.md','.txt',
    '.yaml','.yml','.toml','.sql','.ps1','.psm1','.py','.sh',
    '.html','.css','.scss','.xml','.ini','.conf','.env.example'
)
$allowedNames = @('Dockerfile','Makefile','README','AGENTS.md','.editorconfig','.gitignore','.env.example')
$skipPattern = '[\\/](\.git|node_modules|bin|obj|dist|build|coverage|vendor|\.venv|venv|\.next|target)[\\/]'
$aggregate = New-Object System.Text.StringBuilder
$count = 0

Get-ChildItem -LiteralPath $record.path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $skipPattern -and (
            $allowedExtensions -contains $_.Extension.ToLowerInvariant() -or
            $allowedNames -contains $_.Name
        )
    } |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($record.path.Length).TrimStart([char[]]"\/")
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$aggregate.Append($relative).Append('|').Append($hash).Append([Environment]::NewLine)
        $count++
    }

$currentHash = Get-StringHash $aggregate.ToString()
$stale = $currentHash -ne $oldState.aggregate_sha256

$result = [pscustomobject]@{
    project = $Project
    stale = $stale
    indexed_file_count = $oldState.file_count
    current_file_count = $count
    indexed_sha256 = $oldState.aggregate_sha256
    current_sha256 = $currentHash
}
$result

if ($stale) {
    Write-Host "STALE: run Build-Index.ps1 and New-ProjectSkill.ps1 after reviewing the changes."
}
else {
    Write-Host "CURRENT: index fingerprint matches the registered source files."
}
'@

$enableJev = @'
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [switch]$ApprovedForWork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $Root 'config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Missing config: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($null -eq $config.PSObject.Properties['profile']) { throw "config.profile is missing." }
if ($null -eq $config.PSObject.Properties['external_ai_allowed']) { throw "config.external_ai_allowed is missing." }
if ($null -eq $config.PSObject.Properties['jev'] -or $null -eq $config.jev) { throw "config.jev is missing." }
if ($null -eq $config.jev.PSObject.Properties['enabled']) { throw "config.jev.enabled is missing." }

if ($config.profile -eq 'work' -and -not $ApprovedForWork) {
    throw "Work profile is GLM-only by default. Jev remains blocked. Use -ApprovedForWork only after formal employer approval for this external service."
}

if ($config.profile -eq 'work' -and $ApprovedForWork) {
    Write-Warning "Changing the work profile to permit an external AI service. Confirm current employer approval before sending work content."
}

$config.external_ai_allowed = $true
$config.jev.enabled = $true
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

Write-Host "Jev adapter enabled in local config."
Write-Host "No API key was stored. Set JEV_API_KEY through an approved environment/secret mechanism before use."
'@

$invokeJev = @'
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
'@

$importExistingContext = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Source,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SafeSlug([string]$Value) {
    $leaf = Split-Path -Leaf $Value
    if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = 'context' }
    $slug = $leaf.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    $suffix = (Get-StringSha256 $Value).Substring(0, 8)
    return "$slug-$suffix"
}

function Get-RelativePathCompat([string]$BasePath, [string]$FullPath) {
    $base = $BasePath.TrimEnd([char[]]"\/")
    if ($FullPath.Length -le $base.Length) { return (Split-Path -Leaf $FullPath) }
    return $FullPath.Substring($base.Length).TrimStart([char[]]"\/")
}

function Copy-PreservingConflict {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$SourceSlug
    )

    $parent = Split-Path -Parent $DestinationPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $sourceHash = Get-FileSha256 $SourcePath
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
        return [pscustomobject]@{ action = 'copied'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $targetHash = Get-FileSha256 $DestinationPath
    if ($targetHash -eq $sourceHash) {
        return [pscustomobject]@{ action = 'identical-skip'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $dir = Split-Path -Parent $DestinationPath
    $name = [System.IO.Path]::GetFileNameWithoutExtension($DestinationPath)
    $ext = [System.IO.Path]::GetExtension($DestinationPath)
    $conflictName = "$name.imported-$SourceSlug-$($sourceHash.Substring(0,8))$ext"
    $conflictPath = Join-Path $dir $conflictName

    if (-not (Test-Path -LiteralPath $conflictPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $conflictPath
        return [pscustomobject]@{ action = 'conflict-preserved'; path = $conflictPath; sha256 = $sourceHash }
    }

    if ((Get-FileSha256 $conflictPath) -eq $sourceHash) {
        return [pscustomobject]@{ action = 'conflict-identical-skip'; path = $conflictPath; sha256 = $sourceHash }
    }

    throw "Unexpected hash collision while importing '$SourcePath'."
}

function Merge-GlobalMemory {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$SourceDisplay
    )

    $sourceText = Get-Content -LiteralPath $SourcePath -Raw
    $sourceHash = Get-FileSha256 $SourcePath
    $marker = "<!-- context-spine-import sha256:$sourceHash -->"

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        $parent = Split-Path -Parent $DestinationPath
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
        return [pscustomobject]@{ action = 'canonical-created'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $current = Get-Content -LiteralPath $DestinationPath -Raw
    if ($current.Contains($marker)) {
        return [pscustomobject]@{ action = 'canonical-already-imported'; path = $DestinationPath; sha256 = $sourceHash }
    }

    if ((Get-FileSha256 $DestinationPath) -eq $sourceHash) {
        return [pscustomobject]@{ action = 'canonical-identical-skip'; path = $DestinationPath; sha256 = $sourceHash }
    }

    $block = @"

$marker
## Imported legacy context

Source: $SourceDisplay
Imported UTC: $([DateTime]::UtcNow.ToString('o'))

$sourceText
<!-- /context-spine-import -->
"@
    Add-Content -LiteralPath $DestinationPath -Value $block -Encoding UTF8
    return [pscustomobject]@{ action = 'canonical-appended'; path = $DestinationPath; sha256 = $sourceHash }
}

$rootFull = [System.IO.Path]::GetFullPath($Root)
$importsRoot = Join-Path $Root 'imports'
$migrationsRoot = Join-Path $Root 'migrations'
New-Item -ItemType Directory -Force -Path $importsRoot, $migrationsRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]

foreach ($sourceInput in $Source) {
    if ([string]::IsNullOrWhiteSpace($sourceInput)) { continue }
    if (-not (Test-Path -LiteralPath $sourceInput -PathType Container)) {
        Write-Warning "Legacy context source not found: $sourceInput"
        continue
    }

    $sourceRoot = (Resolve-Path -LiteralPath $sourceInput).Path
    if ([System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('\') -eq $rootFull.TrimEnd('\')) {
        Write-Host "SKIP import source because it is the active Context Spine root: $sourceRoot"
        continue
    }

    $sourceSlug = Get-SafeSlug $sourceRoot
    $rawRoot = Join-Path $importsRoot $sourceSlug
    New-Item -ItemType Directory -Force -Path $rawRoot | Out-Null

    $memoryCandidate = Join-Path $sourceRoot 'memory'
    $isOpenCodeRoot = Test-Path -LiteralPath $memoryCandidate -PathType Container
    $memoryRoot = if ($isOpenCodeRoot) { $memoryCandidate } else { $sourceRoot }

    $snapshotFiles = @(if ($isOpenCodeRoot) {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $rel = Get-RelativePathCompat $sourceRoot $_.FullName
                $rel -match '^(memory|commands|skills)[\\/]' -or $_.Name -in @('AGENTS.md','opencode.json')
            }
    }
    else {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue
    })

    $actions = New-Object System.Collections.Generic.List[object]

    foreach ($file in $snapshotFiles) {
        $relative = Get-RelativePathCompat $sourceRoot $file.FullName
        $dest = Join-Path $rawRoot $relative
        $action = Copy-PreservingConflict -SourcePath $file.FullName -DestinationPath $dest -SourceSlug $sourceSlug
        $actions.Add([ordered]@{
            scope = 'raw-snapshot'
            source = $file.FullName
            destination = $action.path
            action = $action.action
            sha256 = $action.sha256
        })
    }

    foreach ($name in @('MEMORY.md','lessons.md','preferences.md')) {
        $sourcePath = Join-Path $memoryRoot $name
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            $destPath = Join-Path (Join-Path $Root 'memory') $name
            $action = Merge-GlobalMemory -SourcePath $sourcePath -DestinationPath $destPath -SourceDisplay $sourcePath
            $actions.Add([ordered]@{
                scope = 'canonical-global'
                source = $sourcePath
                destination = $action.path
                action = $action.action
                sha256 = $action.sha256
            })
        }
    }

    $legacyProjects = Join-Path $memoryRoot 'projects'
    if (Test-Path -LiteralPath $legacyProjects -PathType Container) {
        Get-ChildItem -LiteralPath $legacyProjects -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $relative = Get-RelativePathCompat $legacyProjects $_.FullName
            $dest = Join-Path (Join-Path $Root 'memory/projects') $relative
            $action = Copy-PreservingConflict -SourcePath $_.FullName -DestinationPath $dest -SourceSlug $sourceSlug
            $actions.Add([ordered]@{
                scope = 'canonical-project'
                source = $_.FullName
                destination = $action.path
                action = $action.action
                sha256 = $action.sha256
            })
        }
    }

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $manifestPath = Join-Path $migrationsRoot ("import-$stamp-$sourceSlug.json")
    $manifest = [ordered]@{
        schema = 'context-spine-import-v1'
        imported_at_utc = [DateTime]::UtcNow.ToString('o')
        source_root = $sourceRoot
        source_slug = $sourceSlug
        source_preserved = $true
        raw_snapshot_root = $rawRoot
        actions = $actions
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    $results.Add([pscustomobject]@{
        source = $sourceRoot
        raw_snapshot = $rawRoot
        manifest = $manifestPath
        actions = $actions.Count
        source_preserved = $true
    })

    Write-Host "Imported legacy context from: $sourceRoot"
    Write-Host "Original source was not modified or deleted."
    Write-Host "Audit manifest: $manifestPath"

    $verifier = Join-Path $PSScriptRoot 'Test-ImportedContext.ps1'
    if (Test-Path -LiteralPath $verifier -PathType Leaf) {
        & $verifier -ManifestPath $manifestPath | Out-Host
        Write-Host "Import verification: PASSED"
    }
    else {
        Write-Warning "Test-ImportedContext.ps1 was not found; run an import verification after installing the full Context Spine."
    }
}

$results
'@

$testImportedContext = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Import manifest not found: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($null -eq $manifest.PSObject.Properties['actions']) {
    throw "Import manifest is missing the actions collection: $ManifestPath"
}

$actions = @($manifest.actions)
$failures = @()
$checked = 0

foreach ($action in $actions) {
    $checked++

    if ($null -eq $action) {
        $failures += "Import manifest contains a null action."
        continue
    }

    $missingProperties = @()
    foreach ($requiredProperty in @('source','destination','action','sha256')) {
        if ($null -eq $action.PSObject.Properties[$requiredProperty]) {
            $missingProperties += $requiredProperty
        }
    }
    if ($missingProperties.Count -gt 0) {
        $failures += "Import action is missing required properties: $($missingProperties -join ', ')."
        continue
    }

    if (-not (Test-Path -LiteralPath $action.source -PathType Leaf)) {
        $failures += "Original source is missing: $($action.source)"
        continue
    }

    $sourceHash = (Get-FileHash -LiteralPath $action.source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne $action.sha256) {
        $failures += "Original source changed since import: $($action.source)"
    }

    if (-not (Test-Path -LiteralPath $action.destination -PathType Leaf)) {
        $failures += "Imported destination is missing: $($action.destination)"
        continue
    }

    switch ($action.action) {
        { $_ -in @('copied','identical-skip','conflict-preserved','conflict-identical-skip','canonical-created','canonical-identical-skip') } {
            $destHash = (Get-FileHash -LiteralPath $action.destination -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($destHash -ne $action.sha256) {
                $failures += "Imported copy hash mismatch: $($action.destination)"
            }
            break
        }
        { $_ -in @('canonical-appended','canonical-already-imported') } {
            $text = Get-Content -LiteralPath $action.destination -Raw
            if ($null -eq $text) { $text = '' }
            $marker = "<!-- context-spine-import sha256:$($action.sha256) -->"
            if (-not $text.Contains($marker)) {
                $failures += "Canonical memory is missing its import marker: $($action.destination)"
            }
            break
        }
        default {
            $failures += "Unknown import action '$($action.action)' in manifest."
        }
    }
}

$failureList = @($failures)
$result = [pscustomobject]@{
    manifest = $ManifestPath
    source_root = if ($null -ne $manifest.PSObject.Properties['source_root']) { $manifest.source_root } else { $null }
    source_preserved = @($failureList | Where-Object { $_ -like 'Original source*' }).Count -eq 0
    checked_actions = $checked
    failures = $failureList
    verified = ($failureList.Count -eq 0)
}

$result

if ($failureList.Count -gt 0) {
    throw "Existing-context import verification failed. No source cleanup has been attempted. Review the reported failures."
}
'@

$getContextMaintenance = @'
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
'@

$saveCompaction = @'
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
'@

$getBranchSummaryContext = @'
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
'@

$saveBranchSummary = @'
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
'@

$searchMemory = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Pattern,
    [string]$Project,
    [ValidateRange(1,10000)][int]$Limit = 40,
    [switch]$IncludeImports,
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roots = New-Object System.Collections.Generic.List[string]
if ([string]::IsNullOrWhiteSpace($Project)) {
    $roots.Add((Join-Path $Root 'memory'))
    $roots.Add((Join-Path $Root 'context/compactions'))
    $roots.Add((Join-Path $Root 'context/branches'))
}
else {
    $roots.Add((Join-Path (Join-Path $Root 'memory/projects') $Project))
    $roots.Add((Join-Path (Join-Path $Root 'context/compactions') $Project))
    $roots.Add((Join-Path (Join-Path $Root 'context/branches') $Project))
}

if ($IncludeImports) {
    $roots.Add((Join-Path $Root 'imports'))
}

$existing = @($roots | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -Unique)
if ($existing.Count -eq 0) { return }

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -ne $rg) {
    $all = foreach ($searchRoot in $existing) {
        & $rg.Source '--line-number' '--color' 'never' '--fixed-strings' '--glob' '*.md' '--glob' '*.txt' '--glob' '*.json' '--' $Pattern $searchRoot 2>$null
    }
    $all | Select-Object -First $Limit
    return
}

$matches = foreach ($searchRoot in $existing) {
    Get-ChildItem -LiteralPath $searchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.md','.txt','.json') } |
        Select-String -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue
}

$matches | Select-Object -First $Limit | ForEach-Object {
    "$($_.Path):$($_.LineNumber): $($_.Line.Trim())"
}
'@

$testScriptSyntax = @'
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = Join-Path $Root 'scripts'
if (-not (Test-Path -LiteralPath $scriptsDir -PathType Container)) {
    throw "Scripts directory not found: $scriptsDir"
}

$failures = @()
$checked = 0

Get-ChildItem -LiteralPath $scriptsDir -Filter '*.ps1' -File -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object {
        $checked++
        try {
            $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop
            if ($null -eq $content) { $content = '' }
            [void][ScriptBlock]::Create($content)
        }
        catch {
            $failures += [pscustomobject]@{
                file = $_.FullName
                message = $_.Exception.Message
            }
        }
    }

$result = [pscustomobject]@{
    scripts_checked = $checked
    parse_failures = @($failures).Count
    failures = @($failures)
    valid = (@($failures).Count -eq 0)
}
$result

if (@($failures).Count -gt 0) {
    throw "One or more generated Context Spine PowerShell scripts failed parser validation."
}
'@

$testWorkspace = @'
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$required = @(
    'config.json',
    'AGENTS.md',
    'memory/MEMORY.md',
    'memory/lessons.md',
    'memory/preferences.md',
    'scripts/Register-Project.ps1',
    'scripts/Build-Index.ps1',
    'scripts/Search-Context.ps1',
    'scripts/Search-Memory.ps1',
    'scripts/New-ProjectSkill.ps1',
    'scripts/Test-Staleness.ps1',
    'scripts/Import-ExistingContext.ps1',
    'scripts/Test-ImportedContext.ps1',
    'scripts/Test-ScriptSyntax.ps1',
    'scripts/Get-ContextMaintenance.ps1',
    'scripts/Save-Compaction.ps1',
    'scripts/Get-BranchSummaryContext.ps1',
    'scripts/Save-BranchSummary.ps1',
    'scripts/Enable-Jev.ps1',
    'scripts/Invoke-Jev.ps1'
)

$requiredDirs = @(
    'memory/projects',
    'context/compactions',
    'context/branches',
    'context/pending',
    'imports',
    'migrations'
)

$missing = @()
foreach ($item in $required) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing += $item }
}
foreach ($item in $requiredDirs) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { $missing += ($item + '/') }
}

$configPath = Join-Path $Root 'config.json'
$config = $null
$configError = $null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    }
    catch {
        $configError = $_.Exception.Message
    }
}

$profile = Get-OptionalProperty -Object $config -Name 'profile'
$modelProvider = Get-OptionalProperty -Object $config -Name 'model_provider'
$externalAiAllowed = Get-OptionalProperty -Object $config -Name 'external_ai_allowed'
$jev = Get-OptionalProperty -Object $config -Name 'jev'
$compaction = Get-OptionalProperty -Object $config -Name 'compaction'
$jevEnabled = Get-OptionalProperty -Object $jev -Name 'enabled'
$compactionEnabled = Get-OptionalProperty -Object $compaction -Name 'enabled'
$preserveRaw = Get-OptionalProperty -Object $compaction -Name 'preserve_raw'

$configWarnings = @()
if ($null -eq $config) { $configWarnings += 'config.json is missing or unreadable' }
if ([string]::IsNullOrWhiteSpace([string]$profile)) { $configWarnings += 'config.profile is missing' }
if ([string]::IsNullOrWhiteSpace([string]$modelProvider)) { $configWarnings += 'config.model_provider is missing' }
if ($null -eq $compaction) { $configWarnings += 'config.compaction is missing; rerun the current bootstrap with -Force to upgrade generated configuration' }
if ($null -eq $jev) { $configWarnings += 'config.jev is missing; rerun the current bootstrap with -Force to upgrade generated configuration' }

$migrationsPath = Join-Path $Root 'migrations'
$importCount = if (Test-Path -LiteralPath $migrationsPath -PathType Container) {
    @(Get-ChildItem -LiteralPath $migrationsPath -Filter 'import-*.json' -File -ErrorAction SilentlyContinue).Count
}
else {
    0
}

[pscustomobject]@{
    root = $Root
    profile = $profile
    model_provider = $modelProvider
    external_ai_allowed = $externalAiAllowed
    jev_enabled = $jevEnabled
    compaction_enabled = $compactionEnabled
    preserve_raw = $preserveRaw
    legacy_import_manifests = $importCount
    config_error = $configError
    config_warnings = @($configWarnings)
    missing_files = @($missing)
    healthy = ($missing.Count -eq 0 -and $null -eq $configError -and $configWarnings.Count -eq 0)
}
'@

Write-ManagedFile -Path (Join-Path $Root 'config.json') -Content $config
Write-ManagedFile -Path (Join-Path $Root 'AGENTS.md') -Content $globalAgents
Write-ManagedFile -Path (Join-Path $Root 'memory/MEMORY.md') -Content $memory -NeverOverwrite
Write-ManagedFile -Path (Join-Path $Root 'memory/lessons.md') -Content $lessons -NeverOverwrite
Write-ManagedFile -Path (Join-Path $Root 'memory/preferences.md') -Content $preferences -NeverOverwrite
Write-ManagedFile -Path (Join-Path $Root 'memory/projects/PROJECT_TEMPLATE.md') -Content $projectTemplate -NeverOverwrite

$commands = @{
    'ctx-remember.md' = $commandRemember
    'ctx-handover.md' = $commandHandover
    'ctx-memory-status.md' = $commandMemoryStatus
    'ctx-project-skill.md' = $commandProjectSkill
    'ctx-search.md' = $commandSearch
    'ctx-compact.md' = $commandCompact
    'ctx-branch-summary.md' = $commandBranchSummary
}
foreach ($name in $commands.Keys) {
    Write-ManagedFile -Path (Join-Path (Join-Path $Root 'commands') $name) -Content $commands[$name]
}

$scripts = @{
    'Register-Project.ps1' = $registerProject
    'Build-Index.ps1' = $buildIndex
    'Search-Context.ps1' = $searchContext
    'Search-Memory.ps1' = $searchMemory
    'New-ProjectSkill.ps1' = $newProjectSkill
    'Test-Staleness.ps1' = $testStaleness
    'Import-ExistingContext.ps1' = $importExistingContext
    'Test-ImportedContext.ps1' = $testImportedContext
    'Test-ScriptSyntax.ps1' = $testScriptSyntax
    'Get-ContextMaintenance.ps1' = $getContextMaintenance
    'Save-Compaction.ps1' = $saveCompaction
    'Get-BranchSummaryContext.ps1' = $getBranchSummaryContext
    'Save-BranchSummary.ps1' = $saveBranchSummary
    'Enable-Jev.ps1' = $enableJev
    'Invoke-Jev.ps1' = $invokeJev
    'Test-Workspace.ps1' = $testWorkspace
}
foreach ($name in $scripts.Keys) {
    Write-ManagedFile -Path (Join-Path (Join-Path $Root 'scripts') $name) -Content $scripts[$name]
}

Write-Host ""
Write-Host "Validating generated PowerShell scripts..."
& (Join-Path $Root 'scripts/Test-ScriptSyntax.ps1') -Root $Root | Out-Host
Write-Host "Generated script syntax: PASSED"

$legacySources = New-Object System.Collections.Generic.List[string]
if (-not $SkipLegacyImport) {
    $legacyOpenCode = Join-Path (Join-Path $HOME '.config') 'opencode'
    if (Test-Path -LiteralPath $legacyOpenCode -PathType Container) {
        $legacySources.Add($legacyOpenCode)
    }
}
foreach ($candidate in $ImportContextPath) {
    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        $legacySources.Add($candidate)
    }
}

$uniqueLegacySources = @($legacySources | Select-Object -Unique)
if ($uniqueLegacySources.Count -gt 0) {
    Write-Host ""
    Write-Host "Importing existing context additively..."
    & (Join-Path $Root 'scripts/Import-ExistingContext.ps1') -Source $uniqueLegacySources -Root $Root
}

$localReadme = @"
# Local AI Context Spine

Profile: $Profile

Core commands:

Register a project:
  $Root/scripts/Register-Project.ps1 -Name "My App" -Path "C:/path/to/repo"

Search registered source:
  $Root/scripts/Search-Context.ps1 -Project "my-app" -Pattern "term"

Search durable/historical memory:
  $Root/scripts/Search-Memory.ps1 -Project "my-app" -Pattern "term"

Check staleness:
  $Root/scripts/Test-Staleness.ps1 -Project "my-app"

Check whether older session context needs compaction:
  $Root/scripts/Get-ContextMaintenance.ps1 -Project "my-app"

Health check:
  $Root/scripts/Test-Workspace.ps1

Migration:
- Legacy ~/.config/opencode memory is imported additively by default.
- Original legacy files are never deleted or overwritten.
- Raw snapshots: $Root/imports
- Import manifests: $Root/migrations

Compaction and branch summaries preserve raw history.
Jev is optional. Work profile blocks it unless explicitly marked approved.
"@
Write-ManagedFile -Path (Join-Path $Root 'README.md') -Content $localReadme

if ($InstallOpenCode) {
    $openCodeRoot = Join-Path (Join-Path $HOME '.config') 'opencode'
    $openCodeCommands = Join-Path $openCodeRoot 'commands'
    New-Item -ItemType Directory -Force -Path $openCodeCommands | Out-Null

    foreach ($name in $commands.Keys) {
        Write-ManagedFile -Path (Join-Path $openCodeCommands $name) -Content $commands[$name] -NeverOverwrite
    }

    $openCodeAgents = Join-Path $openCodeRoot 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $openCodeAgents)) {
        Write-ManagedFile -Path $openCodeAgents -Content $globalAgents
    }
    else {
        $snippet = @"
# AI Context Spine integration snippet

A global OpenCode AGENTS.md already existed, so bootstrap did not modify it.

Review the generated guidance here:
$Root/AGENTS.md

Merge only the parts you want into:
$openCodeAgents
"@
        Write-ManagedFile -Path (Join-Path $Root 'OPENCODE_SNIPPET.md') -Content $snippet
        Write-Warning "Existing OpenCode AGENTS.md preserved. Review $Root/OPENCODE_SNIPPET.md"
    }
}

Write-Host ""
Write-Host "AI Context Spine bootstrap complete."
Write-Host "Profile: $Profile"
Write-Host "Root: $Root"
Write-Host "Network calls made: none"
Write-Host "Provider/model configuration changed: none"
Write-Host ""
& (Join-Path $Root 'scripts/Test-Workspace.ps1') -Root $Root
