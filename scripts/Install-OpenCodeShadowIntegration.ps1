[CmdletBinding()]
param(
    [string]$ShadowRoot = (Join-Path $HOME '.context-spine-shadow'),
    [string]$OpenCodeRoot = (Join-Path (Join-Path $HOME '.config') 'opencode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ShadowRoot -PathType Container)) {
    throw "Verified shadow Context Spine not found: $ShadowRoot"
}
if (-not (Test-Path -LiteralPath $OpenCodeRoot -PathType Container)) {
    throw "Existing OpenCode setup not found: $OpenCodeRoot"
}

$healthScript = Join-Path $ShadowRoot 'scripts\Test-Workspace.ps1'
if (-not (Test-Path -LiteralPath $healthScript -PathType Leaf)) {
    throw "Shadow health-check script not found: $healthScript"
}

$health = & $healthScript -Root $ShadowRoot
if (-not [bool]$health.healthy) {
    throw "Shadow Context Spine is not healthy. Integration was not attempted."
}

$commandsRoot = Join-Path $OpenCodeRoot 'commands'
New-Item -ItemType Directory -Force -Path $commandsRoot | Out-Null

$shadowScriptRoot = Join-Path $ShadowRoot 'scripts'
$commands = [ordered]@{
    'spine-memory-status.md' = @'
---
description: Read-only Context Spine memory status from the verified shadow workspace
---

Use the verified work Context Spine at `%USERPROFILE%\.context-spine-shadow`.

For historical memory retrieval use:
`%USERPROFILE%\.context-spine-shadow\scripts\Search-Memory.ps1`

For workspace health use:
`%USERPROFILE%\.context-spine-shadow\scripts\Test-Workspace.ps1`

For maintenance status use:
`%USERPROFILE%\.context-spine-shadow\scripts\Get-ContextMaintenance.ps1`

Treat repository source as authoritative if memory conflicts with current code.
Do not modify the existing `%USERPROFILE%\.config\opencode` memory while using this command.
'@

    'spine-memory-search.md' = @'
---
description: Search verified Context Spine memory without changing the live OpenCode setup
---

Search the verified work Context Spine for `$ARGUMENTS` by running:

`%USERPROFILE%\.context-spine-shadow\scripts\Search-Memory.ps1 -Root "%USERPROFILE%\.context-spine-shadow" -Pattern "$ARGUMENTS" -IncludeImports`

Read relevant matched files before drawing conclusions.
Repository source overrides historical memory when they conflict.
'@

    'spine-context-search.md' = @'
---
description: Search source for a registered Context Spine project
---

Use the verified work Context Spine at `%USERPROFILE%\.context-spine-shadow`.

Search registered source for `$ARGUMENTS` using:
`%USERPROFILE%\.context-spine-shadow\scripts\Search-Context.ps1`

Read matched source files before making implementation conclusions.
'@

    'spine-context-health.md' = @'
---
description: Check the verified Context Spine shadow workspace
---

Run:
`%USERPROFILE%\.context-spine-shadow\scripts\Test-Workspace.ps1 -Root "%USERPROFILE%\.context-spine-shadow"`

Report the health result exactly. Do not change provider configuration or the live OpenCode setup.
'@
}

$created = @()
foreach ($name in $commands.Keys) {
    $target = Join-Path $commandsRoot $name
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite existing OpenCode command: $target"
    }
}

foreach ($name in $commands.Keys) {
    $target = Join-Path $commandsRoot $name
    Set-Content -LiteralPath $target -Value $commands[$name] -Encoding UTF8
    $created += $target
}

$integrationRoot = Join-Path $ShadowRoot 'integration'
New-Item -ItemType Directory -Force -Path $integrationRoot | Out-Null
$manifestPath = Join-Path $integrationRoot 'opencode-shadow-integration.json'
$manifest = [ordered]@{
    schema = 'context-spine-opencode-shadow-integration-v1'
    installed_at_utc = [DateTime]::UtcNow.ToString('o')
    shadow_root = $ShadowRoot
    opencode_root = $OpenCodeRoot
    created_files = @($created)
    modified_existing_files = $false
    agents_md_modified = $false
    provider_configuration_modified = $false
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host ""
Write-Host "OPENCODE SHADOW INTEGRATION: PASSED"
Write-Host "Created new commands only:"
foreach ($file in $created) { Write-Host "  $file" }
Write-Host "Existing commands overwritten: NO"
Write-Host "AGENTS.md modified: NO"
Write-Host "Provider configuration modified: NO"
Write-Host "Manifest: $manifestPath"

[pscustomobject]@{
    integrated = $true
    created_files = @($created)
    existing_files_overwritten = $false
    agents_md_modified = $false
    provider_configuration_modified = $false
    manifest = $manifestPath
}
