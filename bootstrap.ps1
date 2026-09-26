[CmdletBinding()]
param(
    [ValidateSet('home','work')][string]$Profile = 'home',
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [switch]$InstallOpenCode,
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
4. Use persistent memory for prior decisions/lessons, never as proof of current code state.
5. If generated context conflicts with the repository, the repository wins.

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
description: Create a concise durable handover for the current coding task
---

Create or update a local handover for the current task.

Capture:
- project and current objective
- completed work
- files/components materially changed
- tests/verification run and results
- important decisions and rationale
- unresolved risks/questions
- exact next action

Do not include secrets. Prefer repository references over copying large source blocks.
'@

$commandMemoryStatus = @'
---
description: Summarize relevant local memory and identify stale or conflicting items
---

Review the local AI Context Spine memory relevant to the current project.

Report:
- durable project decisions
- useful lessons
- unresolved handovers
- anything that appears stale or conflicts with current repository truth

Repository source and committed project instructions override memory.
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

$registerProject = @'
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
$projectPath = $record.path
$indexDir = Join-Path $Root 'index'
New-Item -ItemType Directory -Force -Path $indexDir | Out-Null

$allowedExtensions = @(
    '.go','.mod','.sum','.cs','.csproj','.sln','.props','.targets',
    '.ts','.tsx','.js','.jsx','.json','.jsonc','.md','.txt',
    '.yaml','.yml','.toml','.sql','.ps1','.psm1','.py','.sh',
    '.html','.css','.scss','.xml','.ini','.conf','.env.example'
)
$allowedNames = @('Dockerfile','Makefile','README','AGENTS.md','.editorconfig','.gitignore')
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
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [int]$Limit = 40,
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
    exit 0
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
$statePath = Join-Path (Join-Path $Root 'index') ($Project + '.state.json')
$indexPath = Join-Path (Join-Path $Root 'index') ($Project + '.files.jsonl')

if (-not (Test-Path -LiteralPath $statePath) -or -not (Test-Path -LiteralPath $indexPath)) {
    & (Join-Path $PSScriptRoot 'Build-Index.ps1') -Project $Project -Root $Root
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$entries = Get-Content -LiteralPath $indexPath | ForEach-Object { $_ | ConvertFrom-Json }

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
$oldState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json

$allowedExtensions = @(
    '.go','.mod','.sum','.cs','.csproj','.sln','.props','.targets',
    '.ts','.tsx','.js','.jsx','.json','.jsonc','.md','.txt',
    '.yaml','.yml','.toml','.sql','.ps1','.psm1','.py','.sh',
    '.html','.css','.scss','.xml','.ini','.conf','.env.example'
)
$allowedNames = @('Dockerfile','Makefile','README','AGENTS.md','.editorconfig','.gitignore')
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

[pscustomobject]@{
    project = $Project
    stale = $stale
    indexed_file_count = $oldState.file_count
    current_file_count = $count
    indexed_sha256 = $oldState.aggregate_sha256
    current_sha256 = $currentHash
}

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
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing config: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

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
    [Parameter(Mandatory = $true)][string]$State,
    [Parameter(Mandatory = $true)][string]$Question,
    [string]$Root = (Join-Path $HOME '.agent-context'),
    [string]$Model = 'jev-latest'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $Root 'config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing context config: $configPath"
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if (-not $config.external_ai_allowed -or -not $config.jev.enabled) {
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
    Uri = $config.jev.endpoint
    Headers = $headers
    ContentType = 'application/json'
    Body = $body
}
Invoke-RestMethod @params
'@

$testWorkspace = @'
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME '.agent-context')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$required = @(
    'config.json',
    'AGENTS.md',
    'memory/MEMORY.md',
    'memory/lessons.md',
    'memory/preferences.md',
    'scripts/Register-Project.ps1',
    'scripts/Build-Index.ps1',
    'scripts/Search-Context.ps1',
    'scripts/New-ProjectSkill.ps1',
    'scripts/Test-Staleness.ps1',
    'scripts/Enable-Jev.ps1',
    'scripts/Invoke-Jev.ps1'
)

$missing = @()
foreach ($item in $required) {
    $path = Join-Path $Root $item
    if (-not (Test-Path -LiteralPath $path)) {
        $missing += $item
    }
}

$configPath = Join-Path $Root 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

[pscustomobject]@{
    root = $Root
    profile = if ($null -ne $config) { $config.profile } else { $null }
    model_provider = if ($null -ne $config) { $config.model_provider } else { $null }
    external_ai_allowed = if ($null -ne $config) { $config.external_ai_allowed } else { $null }
    jev_enabled = if ($null -ne $config) { $config.jev.enabled } else { $null }
    missing_files = $missing
    healthy = ($missing.Count -eq 0)
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
}
foreach ($name in $commands.Keys) {
    Write-ManagedFile -Path (Join-Path (Join-Path $Root 'commands') $name) -Content $commands[$name]
}

$scripts = @{
    'Register-Project.ps1' = $registerProject
    'Build-Index.ps1' = $buildIndex
    'Search-Context.ps1' = $searchContext
    'New-ProjectSkill.ps1' = $newProjectSkill
    'Test-Staleness.ps1' = $testStaleness
    'Enable-Jev.ps1' = $enableJev
    'Invoke-Jev.ps1' = $invokeJev
    'Test-Workspace.ps1' = $testWorkspace
}
foreach ($name in $scripts.Keys) {
    Write-ManagedFile -Path (Join-Path (Join-Path $Root 'scripts') $name) -Content $scripts[$name]
}

$localReadme = @"
# Local AI Context Spine

Profile: $Profile

Core commands:

Register a project:
  $Root/scripts/Register-Project.ps1 -Name "My App" -Path "C:/path/to/repo"

Search registered source:
  $Root/scripts/Search-Context.ps1 -Project "my-app" -Pattern "term"

Check staleness:
  $Root/scripts/Test-Staleness.ps1 -Project "my-app"

Health check:
  $Root/scripts/Test-Workspace.ps1

Jev is optional. Work profile blocks it unless explicitly marked approved.
"@
Write-ManagedFile -Path (Join-Path $Root 'README.md') -Content $localReadme

if ($InstallOpenCode) {
    $openCodeRoot = Join-Path (Join-Path $HOME '.config') 'opencode'
    $openCodeCommands = Join-Path $openCodeRoot 'commands'
    New-Item -ItemType Directory -Force -Path $openCodeCommands | Out-Null

    foreach ($name in $commands.Keys) {
        Write-ManagedFile -Path (Join-Path $openCodeCommands $name) -Content $commands[$name]
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
