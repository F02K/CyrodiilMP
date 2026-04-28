param(
    [string]$GamePath
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

Write-Host 'Starting CyrodiilMP full research pass...'
if ($GamePath) {
    Write-Host "Requested game path: $GamePath"
}
else {
    Write-Host 'No game path passed. Trying auto-detection and CYRODIILMP_GAME_DIR.'
}
Write-Host ''

$result = New-CyrodiilMPFullResearch -GamePath $GamePath

Write-Host 'Full research pass complete.'
Write-Host "Run path: $($result.RunPath)"
Write-Host "Report: $($result.Report)"
Write-Host "Summary: $($result.Summary)"
Write-Host "Packages: $($result.Packages)"
Write-Host "Legacy data: $($result.LegacyData)"
Write-Host "Executables/DLLs: $($result.Executables)"
Write-Host "INI summary: $($result.IniSummary)"
Write-Host "Largest files: $($result.LargestFiles)"
Write-Host "Layout: $($result.Layout)"
Write-Host "Steam manifests: $($result.SteamManifests)"
Write-Host ''
Write-Host "Total files scanned: $($result.TotalFiles)"
Write-Host "UE package files: $($result.PackageFiles)"
Write-Host "Legacy Bethesda data files: $($result.LegacyDataFiles)"
Write-Host "Executables/DLLs: $($result.ExecutablesAndDlls)"
Write-Host "INI files: $($result.IniFiles)"

if ($result.PackageFiles -eq 0) {
    Write-Warning 'No .pak/.utoc/.ucas files were found. Check that -GamePath points at the real Oblivion Remastered install folder.'
}

Write-Host ''
Write-Host 'Report preview:'
Get-Content -LiteralPath $result.Report | Select-Object -First 60 | ForEach-Object {
    Write-Host "  $_"
}
