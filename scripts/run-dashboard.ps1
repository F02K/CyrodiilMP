param(
    [int]$Port = 5088
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$dashboardProject = Join-Path $root 'dashboard\CyrodiilMP.Dashboard\CyrodiilMP.Dashboard.csproj'

$env:CYRODIILMP_ROOT = $root
$env:CYRODIILMP_DASHBOARD_URL = "http://127.0.0.1:$Port"
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

Write-Host "Starting CyrodiilMP dashboard on $env:CYRODIILMP_DASHBOARD_URL"
Write-Host 'Press Ctrl+C to stop.'
dotnet run --project $dashboardProject --no-restore
