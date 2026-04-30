param(
    [string]$GamePath,
    [string]$BuildDirectory = ''
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ue4ssRoot = Join-Path $projectRoot 'RE-UE4SS'
if (-not $BuildDirectory) {
    $BuildDirectory = Join-Path $ue4ssRoot 'build\cyrodiilmp'
}

$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$targetWin64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
if (-not (Test-Path -LiteralPath $targetWin64Path -PathType Container)) {
    throw "Game path does not look like an Oblivion Remastered install root. Missing folder: $targetWin64Path"
}

$ue4ssDll = Get-ChildItem -LiteralPath $BuildDirectory -Recurse -Filter 'UE4SS.dll' -File | Select-Object -First 1
$proxyDll = Get-ChildItem -LiteralPath $BuildDirectory -Recurse -Filter 'dwmapi.dll' -File | Select-Object -First 1
if (-not $ue4ssDll -or -not $proxyDll) {
    throw "Could not find built UE4SS.dll and dwmapi.dll under $BuildDirectory. Run .\scripts\build-ue4ss.cmd first."
}

$settingsSource = Join-Path $ue4ssRoot 'assets\UE4SS-settings.ini'
$modsSource = Join-Path $ue4ssRoot 'assets\Mods'

Copy-Item -LiteralPath $ue4ssDll.FullName -Destination (Join-Path $targetWin64Path 'UE4SS.dll') -Force
Copy-Item -LiteralPath $proxyDll.FullName -Destination (Join-Path $targetWin64Path 'dwmapi.dll') -Force

if (Test-Path -LiteralPath $settingsSource -PathType Leaf) {
    Copy-Item -LiteralPath $settingsSource -Destination (Join-Path $targetWin64Path 'UE4SS-settings.ini') -Force
}

if (Test-Path -LiteralPath $modsSource -PathType Container) {
    New-Item -ItemType Directory -Path (Join-Path $targetWin64Path 'Mods') -Force | Out-Null
    Copy-Item -Path (Join-Path $modsSource '*') -Destination (Join-Path $targetWin64Path 'Mods') -Recurse -Force
}

Write-Host "Installed UE4SS runtime -> $targetWin64Path"
