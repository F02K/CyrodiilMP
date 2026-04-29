param(
    [string]$GamePath,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$SkipGameClient,
    [switch]$RequireNirnLabUIPlatformOR
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
$targetUiPath = Join-Path $targetRootPath 'UI\cyrodiilmp'
$targetNirnLabPath = Join-Path $targetRootPath 'NirnLabUIPlatformOR'
$targetLaunchScriptPath = Join-Path $targetRootPath 'Launch-CyrodiilMP.cmd'

$sourceGameClientPath = Join-Path $projectRoot "artifacts\native\$Configuration\GameClient"
$sourceStandalonePath = Join-Path $projectRoot "artifacts\native\$Configuration\Standalone"
$sourceUiPath = Join-Path $projectRoot 'game-plugin\UI\cyrodiilmp'
$sourceNirnLabPath = Join-Path $projectRoot "artifacts\native\$Configuration\NirnLabUIPlatformOR"
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
New-Item -ItemType Directory -Path $targetUiPath -Force | Out-Null
New-Item -ItemType Directory -Path $targetNirnLabPath -Force | Out-Null

$settingsPath = Join-Path $targetBootstrapLogPath 'settings.ini'
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    @(
        '# CyrodiilMP standalone bootstrap settings'
        '# Set EnableConsole=false to hide the native debug console.'
        '# Set EnableUEPatternScan=false if a game update makes startup scanning unstable.'
        '# Set EnableNirnLabUI=false to disable the Chromium UI backend.'
        '# Set ShowMainMenuButton=false to keep the backend available but hide the prototype menu button.'
        '[Debug]'
        'EnableConsole=true'
        ''
        '[UEBridge]'
        'EnableUEPatternScan=true'
        ''
        '[UI]'
        'EnableNirnLabUI=true'
        'ShowMainMenuButton=true'
    ) | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    Write-Host "Created bootstrap settings -> $settingsPath"
}

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

if (Test-Path -LiteralPath $sourceUiPath -PathType Container) {
    Copy-Item -Path (Join-Path $sourceUiPath '*') -Destination $targetUiPath -Recurse -Force
    Write-Host "Installed CyrodiilMP UI assets -> $targetUiPath"
}

if (Test-Path -LiteralPath (Join-Path $sourceNirnLabPath 'NirnLabUIPlatform.dll') -PathType Leaf) {
    Copy-Item -Path (Join-Path $sourceNirnLabPath '*') -Destination $targetNirnLabPath -Recurse -Force
    Write-Host "Installed NirnLabUIPlatformOR runtime -> $targetNirnLabPath"
}
else {
    $message = "NirnLabUIPlatformOR runtime was not found at $sourceNirnLabPath. Build it with .\scripts\build-nirnlab-uiplatformor.ps1 -Configuration $Configuration."
    if ($RequireNirnLabUIPlatformOR) {
        throw $message
    }

    Write-Warning $message
    Write-Warning 'The standalone loader will still run, but the Chromium main-menu button is disabled until NirnLabUIPlatform.dll is installed there.'
}

@(
    '@echo off'
    'setlocal'
    'set "SCRIPT_DIR=%~dp0"'
    'set "WIN64_DIR=%SCRIPT_DIR%.."'
    'set "GAME_EXE=%WIN64_DIR%\OblivionRemastered-Win64-Shipping.exe"'
    'set "LAUNCHER=%SCRIPT_DIR%Standalone\CyrodiilMP.Launcher.exe"'
    'set "BOOTSTRAP=%SCRIPT_DIR%Standalone\CyrodiilMP.Bootstrap.dll"'
    '"%LAUNCHER%" --game-exe "%GAME_EXE%" --bootstrap-dll "%BOOTSTRAP%" %*'
    'exit /b %ERRORLEVEL%'
) | Set-Content -LiteralPath $targetLaunchScriptPath -Encoding ASCII
Write-Host "Installed game launcher command -> $targetLaunchScriptPath"

$statusPath = Join-Path $targetStandalonePath 'standalone-install-status.json'
$status = [PSCustomObject]@{
    InstalledAt = (Get-Date).ToString('o')
    Configuration = $Configuration
    GamePath = $resolvedGamePath
    GameExe = $targetExePath
    StandalonePath = $targetStandalonePath
    GameClientPath = $targetGameClientPath
    UiPath = $targetUiPath
    NirnLabUIPlatformORPath = $targetNirnLabPath
    LaunchCommand = $targetLaunchScriptPath
    Settings = $settingsPath
    BootstrapLog = (Join-Path $targetBootstrapLogPath 'Bootstrap.log')
}
$status | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8

Write-Host ''
Write-Host 'Standalone loader installed.'
Write-Host 'Run it with:'
Write-Host "  .\scripts\run-standalone-loader.ps1 -GamePath `"$resolvedGamePath`" -Configuration $Configuration"
Write-Host 'Or from the installed game folder:'
Write-Host "  $targetLaunchScriptPath"
Write-Host ''
Write-Host 'Logs:'
Write-Host "  $($status.BootstrapLog)"
Write-Host "  $(Join-Path $targetGameClientPath 'GameClient.log')"
Write-Host ''
Write-Host 'Pattern scan setting:'
Write-Host "  $settingsPath"
Write-Host ''
Write-Host 'NirnLabUIPlatformOR:'
Write-Host "  $targetNirnLabPath"
