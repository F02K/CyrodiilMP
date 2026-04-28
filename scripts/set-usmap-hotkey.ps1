param(
    [string]$GamePath,
    [string]$Key = 'F6'
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$keybindPath = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\Mods\Keybinds\Scripts\main.lua'
$backupPath = "$keybindPath.bak-CyrodiilMP"

if (-not (Test-Path -LiteralPath $keybindPath -PathType Leaf)) {
    throw "Keybinds main.lua was not found at: $keybindPath"
}

if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    Copy-Item -LiteralPath $keybindPath -Destination $backupPath
    Write-Host "Backup created: $backupPath"
}

$normalizedKey = $Key.ToUpperInvariant()
if ($normalizedKey -notmatch '^[A-Z0-9_]+$') {
    throw "Invalid key name: $Key"
}

$text = Get-Content -LiteralPath $keybindPath -Raw
$text = $text -replace '\["DumpUSMAP"\]\s*=\s*\{\["Key"\]\s*=\s*Key\.[A-Z0-9_]+,\s*\["ModifierKeys"\]\s*=\s*\{ModifierKey\.CONTROL\}\}', ('["DumpUSMAP"]                    = {["Key"] = Key.{0},            ["ModifierKeys"] = {ModifierKey.CONTROL}}' -f $normalizedKey)
Set-Content -LiteralPath $keybindPath -Value $text -Encoding UTF8

Write-Host "DumpUSMAP hotkey set to Ctrl+$normalizedKey"
Write-Host "File: $keybindPath"
Write-Host ''
Write-Host 'Start the game, wait for UE4SS event loop start, then press the hotkey.'
Write-Host 'Expected output: Mappings.usmap in the Win64 folder.'
