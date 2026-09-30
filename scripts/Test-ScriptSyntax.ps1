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
