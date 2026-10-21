param(
    [Parameter(Mandatory = $true)] [string]$Repo,
    [string]$ManifestPath = '',
    [string]$ChangelogPath = ''
)

$ErrorActionPreference = 'Stop'
if (-not $ManifestPath -and -not $ChangelogPath) { throw 'Provide ManifestPath and/or ChangelogPath.' }
if (-not (Get-Command 'gh.exe' -ErrorAction SilentlyContinue)) { throw 'gh CLI not found. Authenticate with: gh auth login' }

function Set-GitHubContentFile([string]$Path, [string]$LocalPath) {
    if (-not (Test-Path -LiteralPath $LocalPath)) { throw "File not found: $LocalPath" }
    $endpoint = "repos/$Repo/contents/$Path"
    $content = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $LocalPath))
    $base64 = [Convert]::ToBase64String($content)

    $existingSha = & gh api $endpoint --jq '.sha' 2>$null
    $getExitCode = $LASTEXITCODE
    $apiArgs = @('api', '--method', 'PUT', $endpoint,
        '-f', "message=Update stable $Path",
        '-f', "content=$base64",
        '-f', 'branch=main')
    if ($getExitCode -eq 0 -and $existingSha) { $apiArgs += @('-f', "sha=$existingSha") }

    & gh @apiArgs
    if ($LASTEXITCODE -ne 0) { throw "Failed to update $Path on $Repo main branch." }
}

if ($ManifestPath) { Set-GitHubContentFile 'manifest.json' $ManifestPath }
if ($ChangelogPath) { Set-GitHubContentFile 'changelog.json' $ChangelogPath }
