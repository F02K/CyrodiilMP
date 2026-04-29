param(
    [string]$GamePath,
    [switch]$IncludeAutoUSMAP,
    [switch]$SkipClientBridgePublish,
    [switch]$SkipNativePlugin,
    [switch]$IncludeUe4ssGameHost
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
$sourceUiPath = Join-Path $projectRoot 'game-plugin\UI'
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$targetModsPath = Join-Path $targetWin64Path 'Mods'
$targetBridgePath = Join-Path $targetWin64Path 'CyrodiilMP\ClientBridge'
$targetGameClientPath = Join-Path $targetWin64Path 'CyrodiilMP\GameClient'
$targetUiPath = Join-Path $targetWin64Path 'CyrodiilMP\UI'
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
New-Item -ItemType Directory -Path $targetGameClientPath -Force | Out-Null
New-Item -ItemType Directory -Path $targetUiPath -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDumpPath -Force | Out-Null
New-Item -ItemType Directory -Path $menuProbePath -Force | Out-Null

$modsToInstall = @(
    'CyrodiilMP_RuntimeInspector',
    'CyrodiilMP_GameClientBootstrap'
)

$retiredMods = @(
    'CyrodiilMP_ConnectButtonPrototype',
    'CyrodiilMP.NativeLoader',
    'CyrodiilMP'
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

if (Test-Path -LiteralPath $sourceUiPath -PathType Container) {
    Copy-Item -Path (Join-Path $sourceUiPath '*') -Destination $targetUiPath -Recurse -Force
    Write-Host "Installed CyrodiilMP UI assets -> $targetUiPath"
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

$installedGameClient = $false
$installedGameHost = $false

if (-not $SkipNativePlugin) {
    $nativeGameClientPath = Join-Path $projectRoot 'artifacts\native\Release\GameClient'
    if (Test-Path -LiteralPath (Join-Path $nativeGameClientPath 'CyrodiilMP.GameClient.dll') -PathType Leaf) {
        Copy-Item -Path (Join-Path $nativeGameClientPath '*') -Destination $targetGameClientPath -Recurse -Force
        Write-Host "Installed CyrodiilMP.GameClient -> $targetGameClientPath"
        $installedGameClient = $true
    }
    else {
        Write-Warning "Native GameClient DLL not found at $nativeGameClientPath"
        Write-Warning 'Build it first with:'
        Write-Warning '  .\scripts\build-native.ps1 -Configuration Release'
    }

    if ($IncludeUe4ssGameHost) {
        $nativeModName = 'CyrodiilMP.GameHost'
        $nativeSourceDir = Join-Path $sourceModsPath $nativeModName
        $nativeTargetDir = Join-Path $targetModsPath $nativeModName
        $nativeDll = Join-Path $nativeSourceDir 'dlls\main.dll'
        $nativeEnabledPath = Join-Path $nativeTargetDir 'enabled.txt'

        if (-not (Test-Path -LiteralPath $nativeDll -PathType Leaf)) {
            Write-Warning "Optional UE4SS GameHost DLL was requested but was not found at $nativeDll"
            Write-Warning 'Build it first with RE-UE4SS available:'
            Write-Warning '  .\scripts\build-native.ps1 -Configuration Release -BuildUe4ssGameHost'
            Write-Warning 'Skipping optional UE4SS GameHost installation for now.'
        }
        else {
            New-Item -ItemType Directory -Path $nativeTargetDir -Force | Out-Null
            Copy-Item -Path (Join-Path $nativeSourceDir '*') -Destination $nativeTargetDir -Recurse -Force
            if (-not (Test-Path -LiteralPath $nativeEnabledPath -PathType Leaf)) {
                New-Item -ItemType File -Path $nativeEnabledPath -Force | Out-Null
            }
            Write-Host "Installed $nativeModName -> $nativeTargetDir"
            $modsToInstall += $nativeModName
            $installedGameHost = $true
        }
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

    $filteredModsList = $modsList
    foreach ($retiredMod in $retiredMods) {
        $retiredPattern = '^\s*' + [Regex]::Escape($retiredMod) + '\s*:'
        $filteredModsList = $filteredModsList | Where-Object { $_ -notmatch $retiredPattern }
    }

    if ($filteredModsList.Count -ne $modsList.Count) {
        Set-Content -LiteralPath $modsListPath -Value $filteredModsList
        Write-Host 'Removed retired CyrodiilMP mod entries from mods.txt'
    }
}

foreach ($retiredMod in $retiredMods) {
    $retiredEnabledPath = Join-Path $targetModsPath "$retiredMod\enabled.txt"
    if (Test-Path -LiteralPath $retiredEnabledPath -PathType Leaf) {
        Remove-Item -LiteralPath $retiredEnabledPath -Force
        Write-Host "Disabled retired mod marker: $retiredMod\enabled.txt"
    }

    $retiredTargetDir = Join-Path $targetModsPath $retiredMod
    if (Test-Path -LiteralPath $retiredTargetDir -PathType Container) {
        Remove-Item -LiteralPath $retiredTargetDir -Recurse -Force
        Write-Host "Removed retired mod folder: $retiredTargetDir"
    }
}

Write-Host ''
Write-Host 'Installed CyrodiilMP UE4SS mods.'
Write-Host 'Start the game and wait at the main menu.'
Write-Host 'Runtime dumps should appear in:'
Write-Host $runtimeDumpPath
Write-Host 'Menu probe dumps should appear in:'
Write-Host $menuProbePath
Write-Host 'Native GameClient folder:'
Write-Host $targetGameClientPath
Write-Host 'UI assets folder:'
Write-Host $targetUiPath
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
if ($SkipNativePlugin) {
    Write-Host 'Native GameClient: skipped.'
}
elseif ($installedGameClient) {
    Write-Host 'Native GameClient: installed. This is the current native connection path.'
}
else {
    Write-Host 'Native GameClient: missing. Build it with .\scripts\build-native.ps1 -Configuration Release'
}

if ($IncludeUe4ssGameHost) {
    if ($installedGameHost) {
        Write-Host 'Optional UE4SS GameHost: installed.'
    }
    else {
        Write-Host 'Optional UE4SS GameHost: requested but not installed. Build with -BuildUe4ssGameHost after RE-UE4SS deps are available.'
    }
}
else {
    Write-Host 'Optional UE4SS GameHost: not requested. Pass -IncludeUe4ssGameHost only when that experimental path is built.'
}

Write-Host 'Research tools:   CyrodiilMP_RuntimeInspector (Lua)'
Write-Host 'Menu bootstrap:   CyrodiilMP_GameClientBootstrap only loads the native DLL; UI edits belong to native GameHost'
Write-Host 'Retired mods:     CyrodiilMP.NativeLoader and CyrodiilMP_ConnectButtonPrototype are disabled/removed from mods.txt'
Write-Host ''
Write-Host 'Build the standalone native GameClient before installing if you want the non-Lua path:'
Write-Host '  .\scripts\build-native.ps1 -Configuration Release'
