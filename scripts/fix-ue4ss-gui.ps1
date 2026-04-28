param(
    [string]$GamePath
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$win64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$settingsPath = Join-Path $win64Path 'UE4SS-settings.ini'
$backupPath = "$settingsPath.bak-CyrodiilMP"

if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    throw "UE4SS-settings.ini was not found at: $settingsPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $win64Path 'UE4SS.dll') -PathType Leaf)) {
    Write-Warning "UE4SS.dll was not found in $win64Path"
}

if (-not (Test-Path -LiteralPath (Join-Path $win64Path 'dwmapi.dll') -PathType Leaf)) {
    Write-Warning "dwmapi.dll was not found in $win64Path. UE4SS may not load."
}

if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    Copy-Item -LiteralPath $settingsPath -Destination $backupPath
    Write-Host "Backup created: $backupPath"
}
else {
    Write-Host "Backup already exists: $backupPath"
}

$text = Get-Content -LiteralPath $settingsPath -Raw
$text = $text -replace '(?m)^MajorVersion\s*=.*$', 'MajorVersion = 5'
$text = $text -replace '(?m)^MinorVersion\s*=.*$', 'MinorVersion = 3'
$text = $text -replace '(?m)^ConsoleEnabled\s*=.*$', 'ConsoleEnabled = 1'
$text = $text -replace '(?m)^GuiConsoleEnabled\s*=.*$', 'GuiConsoleEnabled = 1'
$text = $text -replace '(?m)^GuiConsoleVisible\s*=.*$', 'GuiConsoleVisible = 1'
$text = $text -replace '(?m)^GraphicsAPI\s*=.*$', 'GraphicsAPI = dx11'
Set-Content -LiteralPath $settingsPath -Value $text -Encoding UTF8

Write-Host ''
Write-Host 'UE4SS GUI settings updated:'
Get-Content -LiteralPath $settingsPath |
    Select-String -Pattern 'MajorVersion|MinorVersion|ConsoleEnabled|GuiConsoleEnabled|GuiConsoleVisible|GraphicsAPI' |
    ForEach-Object { Write-Host "  $($_.Line)" }

Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Start Oblivion Remastered.'
Write-Host '  2. If the GUI opens, go to Dumpers > Generate .usmap file.'
Write-Host '  3. If no GUI opens, try Alt+Tab because it may open behind the game.'
Write-Host '  4. Check for UE4SS.log in the Win64 folder if it still does not load.'
