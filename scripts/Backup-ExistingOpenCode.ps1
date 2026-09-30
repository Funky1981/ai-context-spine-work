[CmdletBinding()]
param(
    [string]$Source = (Join-Path (Join-Path $HOME '.config') 'opencode'),
    [string]$BackupParent = $HOME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Existing OpenCode setup was not found: $Source"
}

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$backupPath = Join-Path $BackupParent ("opencode-context-backup-" + $stamp)

if (Test-Path -LiteralPath $backupPath) {
    throw "Backup destination already exists: $backupPath"
}

Write-Host "Source will remain untouched:"
Write-Host "  $Source"
Write-Host ""
Write-Host "Creating verified backup:"
Write-Host "  $backupPath"

Copy-Item -LiteralPath $Source -Destination $backupPath -Recurse -ErrorAction Stop

$sourceFiles = @(
    Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction Stop |
        Sort-Object FullName
)
$backupFiles = @(
    Get-ChildItem -LiteralPath $backupPath -Recurse -File -ErrorAction Stop |
        Sort-Object FullName
)

if ($sourceFiles.Count -ne $backupFiles.Count) {
    throw "Backup verification failed: source has $($sourceFiles.Count) files but backup has $($backupFiles.Count). Nothing has been deleted from the source."
}

$failures = @()

foreach ($sourceFile in $sourceFiles) {
    $relative = $sourceFile.FullName.Substring($Source.TrimEnd([char[]]"\/").Length).TrimStart([char[]]"\/")
    $backupFile = Join-Path $backupPath $relative

    if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) {
        $failures += "Missing backup file: $relative"
        continue
    }

    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    $backupHash = (Get-FileHash -LiteralPath $backupFile -Algorithm SHA256).Hash

    if ($sourceHash -ne $backupHash) {
        $failures += "Hash mismatch: $relative"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Backup verification failed. The original OpenCode setup has not been modified."
}

Write-Host ""
Write-Host "BACKUP VERIFIED: PASSED"
Write-Host "Files verified: $($sourceFiles.Count)"
Write-Host "Backup path: $backupPath"
Write-Host "Original OpenCode setup was not modified."

[pscustomobject]@{
    source = $Source
    backup = $backupPath
    files_verified = $sourceFiles.Count
    verified = $true
    source_modified = $false
}
