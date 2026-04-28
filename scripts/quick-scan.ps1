param(
    [string]$GamePath
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$result = New-CyrodiilMPGameInventory -GamePath $GamePath

Write-Host 'CyrodiilMP quick scan complete.'
Write-Host "Game path: $($result.GamePath)"
Write-Host "Indexed files: $($result.FileCount)"
Write-Host "Executables: $($result.ExecutableFileCount)"
Write-Host "UE package files: $($result.PackageFileCount)"
Write-Host "Markdown: $($result.Markdown)"
Write-Host "JSON: $($result.Json)"

if ($result.FileCount -eq 0) {
    Write-Warning 'No matching files were found. The game path may not point at the actual Oblivion Remastered install folder.'
}
elseif ($result.PackageFileCount -eq 0) {
    Write-Warning 'No .pak/.utoc/.ucas files were found. If this is the real game folder, the package layout may be different than expected.'
}

Write-Host ''
Write-Host 'Markdown preview:'
Get-Content -LiteralPath $result.Markdown | Select-Object -First 30 | ForEach-Object {
    Write-Host "  $_"
}
