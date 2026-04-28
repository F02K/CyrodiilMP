param(
    [string]$GamePath,
    [switch]$IncludeAutoUSMAP,
    [switch]$SkipClientBridgePublish,
    [switch]$SkipNativePlugin
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
    'CyrodiilMP_RuntimeInspector'
    # CyrodiilMP_ConnectButtonPrototype is retired — replaced by the native plugin.
    # Re-add it here only if you need the Lua prototype for debugging.
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

# ── Native plugin (CyrodiilMP.GameHost DLL mod) ───────────────────────────────
if (-not $SkipNativePlugin) {
    $nativeModName   = 'CyrodiilMP.GameHost'
    $nativeSourceDir = Join-Path $projectRoot "game-plugin\UE4SS\Mods\$nativeModName"
    $nativeTargetDir = Join-Path $targetModsPath $nativeModName
    $nativeDll       = Join-Path $nativeSourceDir 'dlls\main.dll'

    if (-not (Test-Path -LiteralPath $nativeDll -PathType Leaf)) {
        Write-Warning "Native plugin DLL not found at $nativeDll"
        Write-Warning "Build it first: cd native && cmake --preset release && cmake --build build/release --config Release"
        Write-Warning "Skipping native plugin installation."
    } else {
        New-Item -ItemType Directory -Path (Join-Path $nativeTargetDir 'dlls') -Force | Out-Null
        Copy-Item -Path $nativeDll -Destination (Join-Path $nativeTargetDir 'dlls\main.dll') -Force
        Write-Host "Installed $nativeModName -> $nativeTargetDir"
        $modsToInstall += $nativeModName
    }
}

# ── Update enabled.txt ────────────────────────────────────────────────────────
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

# Remove the retired Lua connect prototype if it is still enabled.
if ($enabled -contains 'CyrodiilMP_ConnectButtonPrototype') {
    $newEnabled = $enabled | Where-Object { $_ -ne 'CyrodiilMP_ConnectButtonPrototype' }
    Set-Content -LiteralPath $enabledPath -Value $newEnabled
    Write-Host "Disabled retired mod: CyrodiilMP_ConnectButtonPrototype"
}

Write-Host ''
Write-Host 'Installed CyrodiilMP UE4SS mods.'
Write-Host ''
Write-Host 'Native plugin:    CyrodiilMP.GameHost (DLL — handles button + hooks natively)'
Write-Host 'Research tools:   CyrodiilMP_RuntimeInspector (Lua)'
Write-Host 'Client bridge:   ' $targetBridgePath
Write-Host 'Runtime dumps:   ' (Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\CyrodiilMP_RuntimeDumps')
Write-Host ''
Write-Host 'Build the native plugin before installing:'
Write-Host '  cd native'
Write-Host '  cmake --preset release'
Write-Host '  cmake --build build/release --config Release'
