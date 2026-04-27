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
Write-Host "UE package files: $($result.PackageFileCount)"
Write-Host "Markdown: $($result.Markdown)"
Write-Host "JSON: $($result.Json)"
