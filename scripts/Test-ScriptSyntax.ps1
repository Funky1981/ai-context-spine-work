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

$failures = New-Object System.Collections.Generic.List[object]
$checked = 0

Get-ChildItem -LiteralPath $scriptsDir -Filter '*.ps1' -File -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object {
        $checked++
        [System.Management.Automation.Language.Token[]]$tokens = $null
        [System.Management.Automation.Language.ParseError[]]$parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )

        foreach ($parseError in @($parseErrors)) {
            if ($null -ne $parseError) {
                $failures.Add([pscustomobject]@{
                    file = $_.FullName
                    message = $parseError.Message
                    line = $parseError.Extent.StartLineNumber
                    column = $parseError.Extent.StartColumnNumber
                })
            }
        }
    }

$result = [pscustomobject]@{
    scripts_checked = $checked
    parse_failures = $failures.Count
    failures = @($failures)
    valid = ($failures.Count -eq 0)
}
$result

if ($failures.Count -gt 0) {
    throw "One or more generated Context Spine PowerShell scripts failed parser validation."
}
