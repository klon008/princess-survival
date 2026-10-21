<#
.SYNOPSIS
    Repairs stable game manifests after launcher releases became the newest GitHub Release.

.EXAMPLE
    .\repair-game-release.ps1 -Version 1.0.0
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
if (-not (gh release view "v$Version" -R $Repo 2>$null)) {
    throw "Game release v$Version was not found in $Repo."
}

# Repoint the existing stable metadata at the immutable game release asset.
$manifestPath = Join-Path $DistDir 'manifest.json'
$changelogPath = Join-Path $DistDir 'changelog.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing local manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.version -ne $Version) { throw "Local manifest version is $($manifest.version), expected $Version." }
$manifest.downloadUrl = "https://github.com/$Repo/releases/download/v$Version/$($manifest.zip)"
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'build-changelog.ps1') -OutputPath $changelogPath

Write-Host 'Publishing stable game metadata to the main branch ...'
& (Join-Path $PSScriptRoot 'sync-stable-manifests.ps1') -Repo $Repo -ManifestPath $manifestPath -ChangelogPath $changelogPath

# Older launchers still ask GitHub for /releases/latest/download/manifest.json.
# Keep them working by attaching the stable game metadata to whichever release
# currently owns GitHub's `latest` alias (often a launcher-only release).
$latestTag = gh release view -R $Repo --json tagName --jq '.tagName'
if ($LASTEXITCODE -ne 0 -or -not $latestTag) { throw 'Could not determine the latest GitHub release.' }
Write-Host "Attaching backward-compatible game metadata to latest release $latestTag ..."
gh release upload $latestTag $manifestPath $changelogPath -R $Repo --clobber
if ($LASTEXITCODE -ne 0) { throw "Could not attach game metadata to $latestTag." }

Write-Host "Stable game manifest repaired: https://raw.githubusercontent.com/$Repo/main/manifest.json"
