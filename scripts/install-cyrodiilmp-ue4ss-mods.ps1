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
$targetGameRoot = Join-Path $resolvedGamePath 'OblivionRemastered'
$targetContentPath = Join-Path $targetGameRoot 'Content'
$targetPaksPath = Join-Path $targetContentPath 'Paks'
$sourceModsPath = Join-Path $projectRoot 'game-plugin\UE4SS\Mods'
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$targetModsPath = Join-Path $targetWin64Path 'Mods'
$targetBridgePath = Join-Path $targetWin64Path 'CyrodiilMP\ClientBridge'
$runtimeDumpPath = Join-Path $targetWin64Path 'CyrodiilMP_RuntimeDumps'
$menuProbePath = Join-Path $targetWin64Path 'CyrodiilMP_MenuProbe'
$modsListPath = Join-Path $targetModsPath 'mods.txt'

if (-not (Test-Path -LiteralPath $targetGameRoot -PathType Container)) {
    throw "Game path does not look like an Oblivion Remastered install root. Missing folder: $targetGameRoot"
}

if (-not ((Test-Path -LiteralPath $targetWin64Path -PathType Container) -or (Test-Path -LiteralPath $targetPaksPath -PathType Container))) {
    throw "Game path does not look complete enough for UE4SS install. Expected either $targetWin64Path or $targetPaksPath to exist."
}

New-Item -ItemType Directory -Path $targetWin64Path -Force | Out-Null
New-Item -ItemType Directory -Path $targetModsPath -Force | Out-Null
New-Item -ItemType Directory -Path $targetBridgePath -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDumpPath -Force | Out-Null
New-Item -ItemType Directory -Path $menuProbePath -Force | Out-Null

$modsToInstall = @(
    'CyrodiilMP_RuntimeInspector'
)

if ($IncludeAutoUSMAP) {
    $modsToInstall += 'CyrodiilMP_AutoUSMAP'
}

foreach ($modName in $modsToInstall) {
    $source = Join-Path $sourceModsPath $modName
    $target = Join-Path $targetModsPath $modName
    $modEnabledPath = Join-Path $target 'enabled.txt'

    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Missing source mod: $source"
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
    if (-not (Test-Path -LiteralPath $modEnabledPath -PathType Leaf)) {
        New-Item -ItemType File -Path $modEnabledPath -Force | Out-Null
    }
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

if (-not $SkipNativePlugin) {
    $nativeModName = 'CyrodiilMP.GameHost'
    $nativeSourceDir = Join-Path $sourceModsPath $nativeModName
    $nativeTargetDir = Join-Path $targetModsPath $nativeModName
    $nativeDll = Join-Path $nativeSourceDir 'dlls\main.dll'
    $nativeEnabledPath = Join-Path $nativeTargetDir 'enabled.txt'

    if (-not (Test-Path -LiteralPath $nativeDll -PathType Leaf)) {
        Write-Warning "Native plugin DLL not found at $nativeDll"
        Write-Warning 'Build it first with:'
        Write-Warning '  .\scripts\build-native.ps1 -Configuration Release'
        Write-Warning 'Skipping native plugin installation for now.'
    }
    else {
        New-Item -ItemType Directory -Path $nativeTargetDir -Force | Out-Null
        Copy-Item -Path (Join-Path $nativeSourceDir '*') -Destination $nativeTargetDir -Recurse -Force
        if (-not (Test-Path -LiteralPath $nativeEnabledPath -PathType Leaf)) {
            New-Item -ItemType File -Path $nativeEnabledPath -Force | Out-Null
        }
        Write-Host "Installed $nativeModName -> $nativeTargetDir"
        $modsToInstall += $nativeModName
    }
}

if (Test-Path -LiteralPath $modsListPath -PathType Leaf) {
    $modsList = Get-Content -LiteralPath $modsListPath
    foreach ($modName in $modsToInstall) {
        $pattern = '^\s*' + [Regex]::Escape($modName) + '\s*:'
        if (-not ($modsList | Where-Object { $_ -match $pattern })) {
            Add-Content -LiteralPath $modsListPath -Value "$modName : 1"
            Write-Host "Added $modName to mods.txt"
        }
    }

    $prototypePattern = '^\s*CyrodiilMP_ConnectButtonPrototype\s*:'
    $filteredModsList = $modsList | Where-Object { $_ -notmatch $prototypePattern }
    if ($filteredModsList.Count -ne $modsList.Count) {
        Set-Content -LiteralPath $modsListPath -Value $filteredModsList
        Write-Host 'Disabled retired mod in mods.txt: CyrodiilMP_ConnectButtonPrototype'
    }
}

$prototypeEnabledPath = Join-Path $targetModsPath 'CyrodiilMP_ConnectButtonPrototype\enabled.txt'
if (Test-Path -LiteralPath $prototypeEnabledPath -PathType Leaf) {
    Remove-Item -LiteralPath $prototypeEnabledPath -Force
    Write-Host 'Disabled retired mod marker: CyrodiilMP_ConnectButtonPrototype\enabled.txt'
}

Write-Host ''
Write-Host 'Installed CyrodiilMP UE4SS mods.'
Write-Host 'Start the game and wait at the main menu.'
Write-Host 'Runtime dumps should appear in:'
Write-Host $runtimeDumpPath
Write-Host 'Menu probe dumps should appear in:'
Write-Host $menuProbePath
if ($SkipClientBridgePublish) {
    Write-Host 'Client bridge publish/install was skipped.'
    Write-Host 'Expected client bridge folder:'
    Write-Host $targetBridgePath
}
else {
    Write-Host 'Client bridge is installed in:'
    Write-Host $targetBridgePath
}
Write-Host ''
Write-Host 'Native plugin:    CyrodiilMP.GameHost (DLL, intended long-term connect path)'
Write-Host 'Research tools:   CyrodiilMP_RuntimeInspector (Lua)'
Write-Host 'Connect prototype: CyrodiilMP_ConnectButtonPrototype is no longer installed by default'
Write-Host ''
Write-Host 'Build the native plugin before installing if you want the non-Lua path:'
Write-Host '  .\scripts\build-native.ps1 -Configuration Release'
