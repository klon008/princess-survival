<#
.SYNOPSIS
    Packs the game build into a zip (via 7-Zip) and generates an update manifest.json.

.EXAMPLE
    .\pack-release.ps1 -Version 1.0.0
    .\pack-release.ps1 -Version 1.1.0 -Repo "username/princess-survival"
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,

    # GitHub repo "owner/name". Optional: embeds download URLs into the manifest.
    [string]$Repo = '',

    [string]$SourceDir = '',
    [string]$OutputDir = '',
    [string]$GameName = 'Princess Survival',
    [string]$ZipBaseName = 'PrincessSurvival',

    [string]$SevenZip = '',

    # Rebuild an existing archive instead of reusing it.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty inside param defaults on Windows PowerShell 5.1,
# so resolve paths here in the body.
if (-not $SourceDir) { $SourceDir = $PSScriptRoot }
if (-not $OutputDir) { $OutputDir = Join-Path $PSScriptRoot 'dist' }
if (-not $SevenZip)  { $SevenZip = "$env:ProgramFiles\7-Zip\7z.exe" }

# --- locate 7-Zip ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $SevenZip)) {
    $onPath = Get-Command '7z.exe' -ErrorAction SilentlyContinue
    if ($null -eq $onPath) { throw "7z.exe not found (tried '$SevenZip' and PATH)." }
    $SevenZip = $onPath.Source
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$zipName      = '{0}-{1}-win64.zip' -f $ZipBaseName, $Version
$zipPath      = Join-Path $OutputDir $zipName
$manifestPath = Join-Path $OutputDir 'manifest.json'
$changelogPath = Join-Path $OutputDir 'changelog.json'

if ($Force -and (Test-Path -LiteralPath $zipPath)) {
    Remove-Item -LiteralPath $zipPath -Force
}

if (-not (Test-Path -LiteralPath $zipPath)) {
    Write-Host "Packing '$GameName' v$Version ..."
    # -xr! excludes by name at any depth: build tooling and previous output never get in.
    & $SevenZip a -tzip -mx=7 $zipPath (Join-Path $SourceDir '*') `
        '-xr!dist' '-xr!*.ps1' '-xr!manifest.json' '-xr!changelog.json' `
        '-xr!.git' '-xr!README.md' '-xr!.gitignore' '-xr!changelog' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE." }
}
else {
    Write-Host "Zip already exists, reusing: $zipPath"
}

# --- verify archive entries ---------------------------------------------------
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    $bad = @($entries | Where-Object { $_ -match '\\' })
    if ($bad.Count -gt 0) {
        throw "Archive has backslash-separated entries (must be forward slashes): $($bad -join ', ')"
    }
    $exeMatches = @($entries | Where-Object { $_ -like '*.exe' })
    $exeEntry = if ($exeMatches.Count -gt 0) { [string]$exeMatches[0] } else { $null }
}
finally {
    $zip.Dispose()
}

# --- manifest -----------------------------------------------------------------
$sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$size   = (Get-Item -LiteralPath $zipPath).Length

& (Join-Path $PSScriptRoot 'build-changelog.ps1') -OutputPath $changelogPath
$changelogEntries = @(Get-Content -LiteralPath $changelogPath -Raw -Encoding UTF8 | ConvertFrom-Json)
$currentNotesEntry = $changelogEntries | Where-Object { $_.version -eq $Version } | Select-Object -First 1
$manifestNotes = ''
if ($currentNotesEntry) {
    $noteLines = @($currentNotesEntry.title, '')
    foreach ($section in @(@{ Label = 'Добавлено'; Values = @($currentNotesEntry.added) },
                           @{ Label = 'Изменено'; Values = @($currentNotesEntry.changed) },
                           @{ Label = 'Исправлено'; Values = @($currentNotesEntry.fixed) })) {
        if ($section.Values.Count -gt 0) {
            $noteLines += $section.Label
            foreach ($line in $section.Values) { $noteLines += "• $line" }
            $noteLines += ''
        }
    }
    $manifestNotes = ($noteLines -join "`n").Trim()
}

$manifest = [ordered]@{
    game        = $GameName
    version     = $Version
    channel     = 'stable'
    publishedAt = (Get-Date).ToUniversalTime().ToString('o')
    zip         = $zipName
    sizeBytes   = $size
    sha256      = $sha256
}
if ($exeEntry) { $manifest.exe = $exeEntry }
if ($manifestNotes) { $manifest.notes = $manifestNotes }
if ($Repo) {
    $manifest.repo        = $Repo
    $manifest.downloadUrl = "https://github.com/$Repo/releases/download/v$Version/$zipName"
}

# BOM-less UTF-8: some JSON parsers choke on a BOM.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json), $utf8NoBom)

Write-Host ''
Write-Host "Done. Files in $OutputDir :"
Write-Host "  $zipName      ($([math]::Round($size / 1MB, 1)) MB)"
Write-Host "  manifest.json"
Write-Host "  changelog.json"
Get-Content -LiteralPath $manifestPath
