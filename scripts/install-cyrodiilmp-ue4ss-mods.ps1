param(
    [string]$GamePath,
    [switch]$IncludeAutoUSMAP,
    [switch]$SkipClientBridgePublish
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$sourceModsPath = Join-Path $projectRoot 'game-plugin\UE4SS\Mods'
$targetModsPath = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\Mods'
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$targetBridgePath = Join-Path $targetWin64Path 'CyrodiilMP\ClientBridge'
$enabledPath = Join-Path $targetModsPath 'enabled.txt'

if (-not (Test-Path -LiteralPath $targetModsPath -PathType Container)) {
    throw "UE4SS Mods folder was not found: $targetModsPath"
}

$modsToInstall = @(
    'CyrodiilMP_RuntimeInspector',
    'CyrodiilMP_ConnectButtonPrototype'
)

if ($IncludeAutoUSMAP) {
    $modsToInstall += 'CyrodiilMP_AutoUSMAP'
}

foreach ($modName in $modsToInstall) {
    $source = Join-Path $sourceModsPath $modName
    $target = Join-Path $targetModsPath $modName

    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Missing source mod: $source"
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
    Write-Host "Installed $modName -> $target"
}

if (-not $SkipClientBridgePublish) {
    $publishScript = Join-Path $projectRoot 'build\publish-client-bridge.ps1'
    & $publishScript -Configuration Release

    $publishedBridgePath = Join-Path $projectRoot 'artifacts\publish\client-bridge'
    if (-not (Test-Path -LiteralPath (Join-Path $publishedBridgePath 'CyrodiilMP.ClientBridge.exe') -PathType Leaf)) {
        throw "Published client bridge executable was not found in $publishedBridgePath"
    }

    New-Item -ItemType Directory -Path $targetBridgePath -Force | Out-Null
    Copy-Item -Path (Join-Path $publishedBridgePath '*') -Destination $targetBridgePath -Recurse -Force
    Write-Host "Installed CyrodiilMP.ClientBridge -> $targetBridgePath"
}

if (-not (Test-Path -LiteralPath $enabledPath -PathType Leaf)) {
    New-Item -ItemType File -Path $enabledPath -Force | Out-Null
}

$enabled = @(Get-Content -LiteralPath $enabledPath -ErrorAction SilentlyContinue)
foreach ($modName in $modsToInstall) {
    if ($enabled -notcontains $modName) {
        Add-Content -LiteralPath $enabledPath -Value $modName
        Write-Host "Enabled $modName"
    }
}

Write-Host ''
Write-Host 'Installed CyrodiilMP UE4SS mods.'
Write-Host 'Start the game and wait at the main menu.'
Write-Host 'Runtime dumps should appear in:'
Write-Host (Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\CyrodiilMP_RuntimeDumps')
Write-Host 'Menu probe dumps should appear in:'
Write-Host (Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\CyrodiilMP_MenuProbe')
Write-Host 'Client bridge is installed in:'
Write-Host $targetBridgePath
Write-Host ''
Write-Host 'Console commands are optional; the helpers also run automatically after launch.'
Write-Host 'Optional console commands:'
Write-Host '  cyro_dump_runtime'
Write-Host '  cyro_dump_ui'
Write-Host '  cyro_menu_probe'
Write-Host '  cyro_connect'
