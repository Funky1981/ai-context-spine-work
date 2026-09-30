[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [string]$Project,
    [int]$Limit = 40,
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
    exit 0
}

$matches = foreach ($searchRoot in $existing) {
    Get-ChildItem -LiteralPath $searchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.md','.txt','.json') } |
        Select-String -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue
}

$matches | Select-Object -First $Limit | ForEach-Object {
    "$($_.Path):$($_.LineNumber): $($_.Line.Trim())"
}
