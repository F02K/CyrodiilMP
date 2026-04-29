param(
    [string]$GamePath,
    [switch]$IncludeAutoUSMAP
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
$runtimeDumpPath = Join-Path $targetWin64Path 'CyrodiilMP_RuntimeDumps'
$menuProbePath = Join-Path $targetWin64Path 'CyrodiilMP_MenuProbe'
$modsListPath = Join-Path $targetModsPath 'mods.txt'

if (-not (Test-Path -LiteralPath $targetGameRoot -PathType Container)) {
    throw "Game path does not look like an Oblivion Remastered install root. Missing folder: $targetGameRoot"
}

if (-not ((Test-Path -LiteralPath $targetWin64Path -PathType Container) -or (Test-Path -LiteralPath $targetPaksPath -PathType Container))) {
    throw "Game path does not look complete enough for UE4SS research helper install. Expected either $targetWin64Path or $targetPaksPath to exist."
}

New-Item -ItemType Directory -Path $targetWin64Path -Force | Out-Null
New-Item -ItemType Directory -Path $targetModsPath -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDumpPath -Force | Out-Null
New-Item -ItemType Directory -Path $menuProbePath -Force | Out-Null

$modsToInstall = @(
    'CyrodiilMP_RuntimeInspector'
)

$retiredRuntimeMods = @(
    'CyrodiilMP.GameHost',
    'CyrodiilMP_GameClientBootstrap',
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
    Write-Host "Installed UE4SS research helper $modName -> $target"
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
    foreach ($retiredMod in $retiredRuntimeMods) {
        $retiredPattern = '^\s*' + [Regex]::Escape($retiredMod) + '\s*:'
        $filteredModsList = $filteredModsList | Where-Object { $_ -notmatch $retiredPattern }
    }

    if ($filteredModsList.Count -ne $modsList.Count) {
        Set-Content -LiteralPath $modsListPath -Value $filteredModsList
        Write-Host 'Removed retired CyrodiilMP runtime mod entries from mods.txt'
    }
}

foreach ($retiredMod in $retiredRuntimeMods) {
    $retiredEnabledPath = Join-Path $targetModsPath "$retiredMod\enabled.txt"
    if (Test-Path -LiteralPath $retiredEnabledPath -PathType Leaf) {
        Remove-Item -LiteralPath $retiredEnabledPath -Force
        Write-Host "Disabled retired runtime mod marker: $retiredMod\enabled.txt"
    }

    $retiredTargetDir = Join-Path $targetModsPath $retiredMod
    if (Test-Path -LiteralPath $retiredTargetDir -PathType Container) {
        Remove-Item -LiteralPath $retiredTargetDir -Recurse -Force
        Write-Host "Removed retired runtime mod folder: $retiredTargetDir"
    }
}

Write-Host ''
Write-Host 'Installed CyrodiilMP UE4SS research helpers.'
Write-Host 'UE4SS is used only for dumps/runtime inspection; gameplay, UI, and networking belong to the standalone launcher/bootstrap path.'
Write-Host 'Runtime dumps should appear in:'
Write-Host $runtimeDumpPath
Write-Host 'Menu probe dumps should appear in:'
Write-Host $menuProbePath
Write-Host ''
Write-Host 'Installed research helpers:'
foreach ($modName in $modsToInstall) {
    Write-Host "  $modName"
}
