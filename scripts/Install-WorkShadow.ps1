[CmdletBinding()]
param(
    [string]$BootstrapPath = (Join-Path $PSScriptRoot 'bootstrap.ps1'),
    [string]$ShadowRoot = (Join-Path $HOME '.context-spine-shadow'),
    [string]$ExistingOpenCode = (Join-Path (Join-Path $HOME '.config') 'opencode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Path([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]"\/")
}

$protectedOpenCode = Normalize-Path $ExistingOpenCode
$protectedOldContext = Normalize-Path (Join-Path $HOME '.agent-context')
$shadow = Normalize-Path $ShadowRoot

if ($shadow -eq $protectedOpenCode) { throw "Refusing to use the live OpenCode directory as the shadow root." }
if ($shadow -eq $protectedOldContext) { throw "Refusing to use the existing .agent-context directory as the shadow root." }
if (-not (Test-Path -LiteralPath $ExistingOpenCode -PathType Container)) { throw "Existing OpenCode setup was not found: $ExistingOpenCode" }
if (-not (Test-Path -LiteralPath $BootstrapPath -PathType Leaf)) { throw "bootstrap.ps1 was not found: $BootstrapPath" }
if (Test-Path -LiteralPath $ShadowRoot) { throw "Shadow root already exists: $ShadowRoot. Stop and review it before retrying; this script will not overwrite an existing shadow install." }

Write-Host "Protected live OpenCode setup:"
Write-Host "  $ExistingOpenCode"
Write-Host ""
Write-Host "Existing partial Context Spine install will be ignored:"
Write-Host "  $HOME\.agent-context"
Write-Host ""
Write-Host "Creating isolated shadow install:"
Write-Host "  $ShadowRoot"
Write-Host ""

& $BootstrapPath -Profile work -Root $ShadowRoot -ImportContextPath $ExistingOpenCode -SkipLegacyImport

$workspace = & (Join-Path $ShadowRoot 'scripts\Test-Workspace.ps1') -Root $ShadowRoot
if (-not [bool]$workspace.healthy) { throw "Shadow workspace health check failed." }

$latestManifest = Get-ChildItem -LiteralPath (Join-Path $ShadowRoot 'migrations') -Filter 'import-*.json' -File -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($null -eq $latestManifest) { throw "No import manifest was created in the shadow install." }

$verification = & (Join-Path $ShadowRoot 'scripts\Test-ImportedContext.ps1') -ManifestPath $latestManifest.FullName
if (-not [bool]$verification.verified) { throw "Shadow import verification failed." }

Write-Host ""
Write-Host "WORK SHADOW INSTALL: PASSED"
Write-Host "Shadow root: $ShadowRoot"
Write-Host "Live OpenCode setup was not modified."
Write-Host "Existing .agent-context install was not modified."

[pscustomobject]@{
    shadow_root = $ShadowRoot
    live_opencode = $ExistingOpenCode
    live_opencode_modified = $false
    existing_agent_context_modified = $false
    workspace_healthy = [bool]$workspace.healthy
    import_verified = [bool]$verification.verified
}
