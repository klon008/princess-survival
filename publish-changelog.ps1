<#
.SYNOPSIS
    Rebuilds the changelog bundle and attaches it to an existing GitHub Release.

.EXAMPLE
    .\publish-changelog.ps1 -Version 1.0.0
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,
    [string]$Repo = 'klon008/princess-survival',
    [string]$DistDir = ''
)

$ErrorActionPreference = 'Stop'
if (-not $DistDir) { $DistDir = Join-Path $PSScriptRoot 'dist' }
if (-not (Get-Command 'gh.exe' -ErrorAction SilentlyContinue)) {
    throw 'gh CLI not found. Install it, then authenticate with: gh auth login'
}

$changelogPath = Join-Path $DistDir 'changelog.json'
& (Join-Path $PSScriptRoot 'build-changelog.ps1') -OutputPath $changelogPath
$tag = "v$Version"
if (-not (gh release view $tag -R $Repo 2>$null)) {
    throw "Release $tag was not found in $Repo."
}

Write-Host "Uploading changelog.json to $tag ..."
gh release upload $tag $changelogPath -R $Repo --clobber
if ($LASTEXITCODE -ne 0) { throw "gh release upload failed with exit code $LASTEXITCODE." }

$entries = @(Get-Content -LiteralPath $changelogPath -Raw | ConvertFrom-Json)
$entry = $entries | Where-Object { $_.version -eq $Version } | Select-Object -First 1
if ($entry) {
    $noteLines = @($entry.title, '')
    foreach ($section in @(@{ Label = 'Добавлено'; Values = @($entry.added) },
                           @{ Label = 'Изменено'; Values = @($entry.changed) },
                           @{ Label = 'Исправлено'; Values = @($entry.fixed) })) {
        if ($section.Values.Count -gt 0) {
            $noteLines += "### $($section.Label)"
            foreach ($line in $section.Values) { $noteLines += "- $line" }
            $noteLines += ''
        }
    }
    $releaseNotes = $noteLines -join "`n"
    gh release edit $tag -R $Repo --notes $releaseNotes
    if ($LASTEXITCODE -ne 0) { throw "gh release edit failed with exit code $LASTEXITCODE." }
}
Write-Host "Updated: https://github.com/$Repo/releases/tag/$tag"
