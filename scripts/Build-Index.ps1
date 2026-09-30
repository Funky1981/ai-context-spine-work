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
