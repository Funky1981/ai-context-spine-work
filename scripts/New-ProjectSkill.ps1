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
