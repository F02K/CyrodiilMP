$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

Open-CyrodiilMPFModel
Write-Host 'Opened FModel.'
