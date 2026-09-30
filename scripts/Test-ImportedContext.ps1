[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Import manifest not found: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($null -eq $manifest.PSObject.Properties['actions']) {
    throw "Import manifest is missing the actions collection: $ManifestPath"
}
$actions = @($manifest.actions)
$failures = New-Object System.Collections.Generic.List[string]
$checked = 0

foreach ($action in $actions) {
    $checked++

    if ($null -eq $action) {
        $failures.Add("Import manifest contains a null action.")
        continue
    }
    foreach ($requiredProperty in @('source','destination','action','sha256')) {
        if ($null -eq $action.PSObject.Properties[$requiredProperty]) {
            $failures.Add("Import action is missing required property '$requiredProperty'.")
        }
    }
    if (@($failures | Where-Object { $_ -like "Import action is missing required property*" }).Count -gt 0 -and
        ($null -eq $action.PSObject.Properties['source'] -or
         $null -eq $action.PSObject.Properties['destination'] -or
         $null -eq $action.PSObject.Properties['action'] -or
         $null -eq $action.PSObject.Properties['sha256'])) {
        continue
    }

    if (-not (Test-Path -LiteralPath $action.source -PathType Leaf)) {
        $failures.Add("Original source is missing: $($action.source)")
        continue
    }

    $sourceHash = (Get-FileHash -LiteralPath $action.source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne $action.sha256) {
        $failures.Add("Original source changed since import: $($action.source)")
    }

    if (-not (Test-Path -LiteralPath $action.destination -PathType Leaf)) {
        $failures.Add("Imported destination is missing: $($action.destination)")
        continue
    }

    switch ($action.action) {
        { $_ -in @('copied','identical-skip','conflict-preserved','conflict-identical-skip','canonical-created','canonical-identical-skip') } {
            $destHash = (Get-FileHash -LiteralPath $action.destination -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($destHash -ne $action.sha256) {
                $failures.Add("Imported copy hash mismatch: $($action.destination)")
            }
            break
        }
        { $_ -in @('canonical-appended','canonical-already-imported') } {
            $text = Get-Content -LiteralPath $action.destination -Raw
            $marker = "<!-- context-spine-import sha256:$($action.sha256) -->"
            if (-not $text.Contains($marker)) {
                $failures.Add("Canonical memory is missing its import marker: $($action.destination)")
            }
            break
        }
        default {
            $failures.Add("Unknown import action '$($action.action)' in manifest.")
        }
    }
}

$result = [pscustomobject]@{
    manifest = $ManifestPath
    source_root = $manifest.source_root
    source_preserved = @($failures | Where-Object { $_ -like 'Original source*' }).Count -eq 0
    checked_actions = $checked
    failures = @($failures)
    verified = ($failures.Count -eq 0)
}

$result

if ($failures.Count -gt 0) {
    throw "Existing-context import verification failed. No source cleanup has been attempted. Review the reported failures."
}
