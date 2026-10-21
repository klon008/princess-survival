<#
.SYNOPSIS
    Publishes a self-contained launcher EXE and updates the stable launcher manifest.

.EXAMPLE
    .\publish-launcher.ps1 -Version 1.0.5
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,
    [string]$Repo = 'klon008/princess-survival',
    [string]$ProjectPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'PrincessLauncher\PrincessLauncher.csproj'),
    [string]$PublishDir = '',
    [string]$StableDistDir = '',
    [string]$NuGetSource = 'https://api.nuget.org/v3/index.json'
)

$ErrorActionPreference = 'Stop'
if (-not $PublishDir) {
    $PublishDir = Join-Path (Split-Path $ProjectPath -Parent) 'bin\Release\net8.0-windows\win-x64\publish'
}
if (-not $StableDistDir) { $StableDistDir = Join-Path $PSScriptRoot 'dist' }
if (-not (Get-Command 'gh.exe' -ErrorAction SilentlyContinue)) {
    throw 'gh CLI not found. Install it, then authenticate with: gh auth login'
}

$publishArgs = @('publish', $ProjectPath, '-c', 'Release', '-p:PublishProfile=WinX64', "-p:Version=$Version", '--source', $NuGetSource)
Write-Host "Publishing Princess Launcher v$Version ..."
& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE." }

$exePath = Join-Path $PublishDir 'PrincessLauncher.exe'
if (-not (Test-Path -LiteralPath $exePath)) { throw "Published EXE not found: $exePath" }
$stableManifestPath = Join-Path $StableDistDir 'manifest.json'
$stableChangelogPath = Join-Path $StableDistDir 'changelog.json'
foreach ($file in @($stableManifestPath, $stableChangelogPath)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing stable game metadata: $file (run release.ps1 or repair-game-release.ps1 first)." }
}
$hash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $exePath).Length
$tag = "launcher-v$Version"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/PrincessLauncher.exe"
$manifest = [ordered]@{
    version = $Version
    exe = 'PrincessLauncher.exe'
    sizeBytes = $size
    sha256 = $hash
    downloadUrl = $downloadUrl
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
$manifestPath = Join-Path $PublishDir 'launcher-manifest.json'
[IO.File]::WriteAllText($manifestPath, $manifestJson + "`n", [Text.UTF8Encoding]::new($false))

if (gh release view $tag -R $Repo 2>$null) { throw "Release $tag already exists in $Repo. Bump the launcher version." }
gh release create $tag $exePath $manifestPath $stableManifestPath $stableChangelogPath -R $Repo --title "Princess Launcher v$Version" --notes "Princess Survival Launcher v$Version"
if ($LASTEXITCODE -ne 0) { throw "gh release create failed with exit code $LASTEXITCODE." }

& (Join-Path $PSScriptRoot 'sync-stable-manifests.ps1') -Repo $Repo -ManifestPath $stableManifestPath -ChangelogPath $stableChangelogPath

$contentsEndpoint = "repos/$Repo/contents/launcher-manifest.json"
$existingSha = & gh api $contentsEndpoint --jq '.sha' 2>$null
$apiExitCode = $LASTEXITCODE
$apiArgs = @('api', '--method', 'PUT', $contentsEndpoint,
    '-f', "message=Publish Princess Launcher v$Version manifest",
    '-f', "content=$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($manifestJson + "`n")))",
    '-f', 'branch=main')
if ($apiExitCode -eq 0 -and $existingSha) { $apiArgs += @('-f', "sha=$existingSha") }
& gh @apiArgs
if ($LASTEXITCODE -ne 0) { throw 'Release uploaded, but updating launcher-manifest.json on main failed.' }

Write-Host ''
Write-Host "Published launcher v${Version}: $downloadUrl"
Write-Host "Stable manifest: https://raw.githubusercontent.com/$Repo/main/launcher-manifest.json"
Write-Host "Single-file output: $exePath"
