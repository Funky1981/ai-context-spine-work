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
