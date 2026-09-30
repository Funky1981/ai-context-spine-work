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
