param(
    [string]$Name = 'manual'
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$result = New-CyrodiilMPResearchRun -Name $Name

Write-Host 'Created research run.'
Write-Host "Path: $($result.Path)"
Write-Host "Notes: $($result.Notes)"
