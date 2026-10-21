<#
.SYNOPSIS
    Publishes the ZIP, manifest, and changelog as a GitHub Release. Requires the gh CLI
    (install once: choco install gh, then: gh auth login).

.EXAMPLE
    .\publish-release.ps1 -Version 1.0.0 -Repo "username/princess-survival"
    .\publish-release.ps1 -Version 1.0.0 -Repo "username/princess-survival" -PruneOld -Keep 3
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$Repo,                                # "owner/name"

    [string]$DistDir = '',
    [string]$ZipBaseName = 'PrincessSurvival',
    [string]$Notes = '',

    # Delete old releases (and their tags) so only the newest $Keep remain.
    [switch]$PruneOld,
    [int]$Keep = 3
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty inside param defaults on Windows PowerShell 5.1.
if (-not $DistDir) { $DistDir = Join-Path $PSScriptRoot 'dist' }

if (-not (Get-Command 'gh.exe' -ErrorAction SilentlyContinue)) {
    throw 'gh CLI not found. Install: choco install gh  (then run: gh auth login)'
}

$zipName      = '{0}-{1}-win64.zip' -f $ZipBaseName, $Version
$zipPath      = Join-Path $DistDir $zipName
$manifestPath = Join-Path $DistDir 'manifest.json'
$changelogPath = Join-Path $DistDir 'changelog.json'

foreach ($f in @($zipPath, $manifestPath, $changelogPath)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Missing file: $f (run pack-release.ps1 first)." }
}

$tag = "v$Version"

# Refuse to silently overwrite an existing release.
if (gh release view $tag -R $Repo 2>$null) {
    throw "Release $tag already exists in $Repo. Delete it first or bump the version."
}

Write-Host "Creating release $tag ..."
$releaseNotes = $Notes
if (-not $releaseNotes) {
    $manifestData = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $releaseNotes = [string]$manifestData.notes
}
if ($releaseNotes) {
    gh release create $tag $zipPath $manifestPath $changelogPath -R $Repo --title $tag --notes $releaseNotes
}
else {
    gh release create $tag $zipPath $manifestPath $changelogPath -R $Repo --title $tag --generate-notes
}
if ($LASTEXITCODE -ne 0) { throw "gh release create failed with exit code $LASTEXITCODE." }

if ($PruneOld) {
    Write-Host "Pruning old releases (keeping $Keep newest) ..."
    $tags = @(gh release list -R $Repo --json tagName --jq '.[].tagName' |
        Where-Object { $_ -ne $tag })
    # list is newest-first; delete everything below the keep line
    for ($i = $Keep - 1; $i -lt $tags.Count; $i++) {
        Write-Host "  deleting $($tags[$i])"
        gh release delete $tags[$i] -R $Repo --cleanup-tag --yes
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete release $($tags[$i])." }
    }
}

Write-Host ''
Write-Host "Published: https://github.com/$Repo/releases/tag/$tag"
Write-Host "Stable download URLs for the launcher (always resolve to the newest release):"
Write-Host "  https://github.com/$Repo/releases/latest/download/manifest.json"
Write-Host "  https://github.com/$Repo/releases/latest/download/$zipName"
Write-Host "  https://github.com/$Repo/releases/latest/download/changelog.json"
