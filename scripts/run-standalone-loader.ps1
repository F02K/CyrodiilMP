param(
    [string]$GamePath,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$Existing,
    [string]$ProcessName = 'OblivionRemastered-Win64-Shipping.exe',
    [string]$GameArgs
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$gameExePath = Join-Path $targetWin64Path 'OblivionRemastered-Win64-Shipping.exe'
$installedStandalonePath = Join-Path $targetWin64Path 'CyrodiilMP\Standalone'
$artifactStandalonePath = Join-Path $projectRoot "artifacts\native\$Configuration\Standalone"

$launcherPath = Join-Path $installedStandalonePath 'CyrodiilMP.Launcher.exe'
$bootstrapPath = Join-Path $installedStandalonePath 'CyrodiilMP.Bootstrap.dll'

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    $launcherPath = Join-Path $artifactStandalonePath 'CyrodiilMP.Launcher.exe'
}

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    $bootstrapPath = Join-Path $artifactStandalonePath 'CyrodiilMP.Bootstrap.dll'
}

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    throw "CyrodiilMP.Launcher.exe not found. Run .\scripts\build-native.ps1 -Configuration $Configuration and .\scripts\install-standalone-loader.ps1 first."
}

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "CyrodiilMP.Bootstrap.dll not found. Run .\scripts\build-native.ps1 -Configuration $Configuration and .\scripts\install-standalone-loader.ps1 first."
}

if (-not $Existing -and -not (Test-Path -LiteralPath $gameExePath -PathType Leaf)) {
    throw "Game executable not found at $gameExePath"
}

$arguments = @()
if ($Existing) {
    $arguments += '--existing'
    $arguments += '--process-name'
    $arguments += $ProcessName
}
else {
    $arguments += '--game-exe'
    $arguments += $gameExePath
    if (-not [string]::IsNullOrWhiteSpace($GameArgs)) {
        $arguments += '--game-args'
        $arguments += $GameArgs
    }
}

$arguments += '--bootstrap-dll'
$arguments += $bootstrapPath

Write-Host "Launcher:  $launcherPath"
Write-Host "Bootstrap: $bootstrapPath"
if ($Existing) {
    Write-Host "Injecting existing process: $ProcessName"
}
else {
    Write-Host "Launching game: $gameExePath"
}
Write-Host ''

& $launcherPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Standalone launcher exited with $LASTEXITCODE"
}

Write-Host ''
Write-Host 'Standalone launcher finished.'
Write-Host 'Check logs under:'
Write-Host (Join-Path $targetWin64Path 'CyrodiilMP\Bootstrap\Bootstrap.log')
Write-Host (Join-Path $targetWin64Path 'CyrodiilMP\GameClient\GameClient.log')
