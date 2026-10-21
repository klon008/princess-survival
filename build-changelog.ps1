<#
.SYNOPSIS
    Combines changelog/<version>.json entries into dist/changelog.json.
#>
param(
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
if (-not $OutputPath) { $OutputPath = Join-Path (Join-Path $PSScriptRoot 'dist') 'changelog.json' }
$sourceDirectory = Join-Path $PSScriptRoot 'changelog'
$entries = @()

if (Test-Path -LiteralPath $sourceDirectory) {
    foreach ($file in Get-ChildItem -LiteralPath $sourceDirectory -Filter '*.json' -File) {
        $entry = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if (-not $entry.version -or -not $entry.date -or -not $entry.title) {
            throw "Changelog entry is missing version, date, or title: $($file.FullName)"
        }
        if ($file.BaseName -ne $entry.version) {
            throw "Changelog filename must match its version ($($entry.version)): $($file.Name)"
        }
        $entries += $entry
    }
}

$orderedEntries = @($entries | Sort-Object { [version]::Parse($_.version) } -Descending)
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$json = ConvertTo-Json -InputObject $orderedEntries -Depth 10
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)
Write-Host "Wrote $($orderedEntries.Count) changelog entries to $OutputPath"
