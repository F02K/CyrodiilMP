param(
    [string]$Name = 'manual'
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$result = New-CyrodiilMPResearchRun -Name $Name

Write-Host 'Created research run.'
Write-Host "Path: $($result.Path)"
Write-Host "Readme: $($result.Readme)"
Write-Host "Notes: $($result.Notes)"
Write-Host "Status: $($result.Status)"
Write-Host ''
Write-Host 'Created files:'
Get-ChildItem -LiteralPath $result.Path -Force | ForEach-Object {
    if ($_.PSIsContainer) {
        Write-Host ("  [dir]  {0}" -f $_.Name)
    }
    else {
        Write-Host ("  [file] {0} ({1} bytes)" -f $_.Name, $_.Length)
    }
}
