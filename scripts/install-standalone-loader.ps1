param(
    [string]$GamePath,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$SkipGameClient
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$targetExePath = Join-Path $targetWin64Path 'OblivionRemastered-Win64-Shipping.exe'
$targetRootPath = Join-Path $targetWin64Path 'CyrodiilMP'
$targetGameClientPath = Join-Path $targetRootPath 'GameClient'
$targetStandalonePath = Join-Path $targetRootPath 'Standalone'
$targetBootstrapLogPath = Join-Path $targetRootPath 'Bootstrap'

$sourceGameClientPath = Join-Path $projectRoot "artifacts\native\$Configuration\GameClient"
$sourceStandalonePath = Join-Path $projectRoot "artifacts\native\$Configuration\Standalone"
$sourceBootstrapDll = Join-Path $sourceStandalonePath 'CyrodiilMP.Bootstrap.dll'
$sourceLauncherExe = Join-Path $sourceStandalonePath 'CyrodiilMP.Launcher.exe'

if (-not (Test-Path -LiteralPath $targetExePath -PathType Leaf)) {
    throw "Game executable not found at $targetExePath. Pass -GamePath pointing at the Oblivion Remastered install root."
}

if (-not (Test-Path -LiteralPath $sourceBootstrapDll -PathType Leaf)) {
    throw "Standalone bootstrap DLL not found at $sourceBootstrapDll. Run .\scripts\build-native.ps1 -Configuration $Configuration first."
}

if (-not (Test-Path -LiteralPath $sourceLauncherExe -PathType Leaf)) {
    throw "Standalone launcher exe not found at $sourceLauncherExe. Run .\scripts\build-native.ps1 -Configuration $Configuration first."
}

New-Item -ItemType Directory -Path $targetGameClientPath -Force | Out-Null
New-Item -ItemType Directory -Path $targetStandalonePath -Force | Out-Null
New-Item -ItemType Directory -Path $targetBootstrapLogPath -Force | Out-Null

if (-not $SkipGameClient) {
    $gameClientDll = Join-Path $sourceGameClientPath 'CyrodiilMP.GameClient.dll'
    if (Test-Path -LiteralPath $gameClientDll -PathType Leaf) {
        Copy-Item -Path (Join-Path $sourceGameClientPath '*') -Destination $targetGameClientPath -Recurse -Force
        Write-Host "Installed CyrodiilMP.GameClient -> $targetGameClientPath"
    }
    else {
        Write-Warning "CyrodiilMP.GameClient.dll not found at $gameClientDll"
        Write-Warning 'The bootstrap will still load, but native server connect helpers will be unavailable until GameClient is installed.'
    }
}

Copy-Item -Path (Join-Path $sourceStandalonePath '*') -Destination $targetStandalonePath -Recurse -Force
Write-Host "Installed standalone loader -> $targetStandalonePath"

$statusPath = Join-Path $targetStandalonePath 'standalone-install-status.json'
$status = [PSCustomObject]@{
    InstalledAt = (Get-Date).ToString('o')
    Configuration = $Configuration
    GamePath = $resolvedGamePath
    GameExe = $targetExePath
    StandalonePath = $targetStandalonePath
    GameClientPath = $targetGameClientPath
    BootstrapLog = (Join-Path $targetBootstrapLogPath 'Bootstrap.log')
}
$status | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8

Write-Host ''
Write-Host 'Standalone loader installed.'
Write-Host 'Run it with:'
Write-Host "  .\scripts\run-standalone-loader.ps1 -GamePath `"$resolvedGamePath`" -Configuration $Configuration"
Write-Host ''
Write-Host 'Logs:'
Write-Host "  $($status.BootstrapLog)"
Write-Host "  $(Join-Path $targetGameClientPath 'GameClient.log')"
