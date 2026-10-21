<#
.SYNOPSIS
    Builds the game archive and publishes it with its update manifest.

.EXAMPLE
    .\release.ps1 -Version 1.0.0
    .\release.ps1 -Version 1.0.0 -PruneOld -Keep 3
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,

    [string]$Repo = 'klon008/princess-survival',
    [string]$SourceDir = '',
    [string]$DistDir = '',
    [string]$SevenZip = '',
    [string]$ZipBaseName = 'PrincessSurvival',
    [string]$Notes = '',
    [switch]$PruneOld,
    [ValidateRange(1, 100)]
    [int]$Keep = 3
)

$ErrorActionPreference = 'Stop'
$packScript = Join-Path $PSScriptRoot 'pack-release.ps1'
$publishScript = Join-Path $PSScriptRoot 'publish-release.ps1'

$packArgs = @{
    Version = $Version
    Repo = $Repo
    ZipBaseName = $ZipBaseName
    Force = $true
}
if ($SourceDir) { $packArgs.SourceDir = $SourceDir }
if ($DistDir) { $packArgs.OutputDir = $DistDir }
if ($SevenZip) { $packArgs.SevenZip = $SevenZip }

Write-Host '==> Packing release'
& $packScript @packArgs

$publishArgs = @{
    Version = $Version
    Repo = $Repo
    ZipBaseName = $ZipBaseName
    Notes = $Notes
}
if ($DistDir) { $publishArgs.DistDir = $DistDir }
if ($PruneOld) { $publishArgs.PruneOld = $true; $publishArgs.Keep = $Keep }

Write-Host '==> Publishing release'
& $publishScript @publishArgs
