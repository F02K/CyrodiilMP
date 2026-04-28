param(
    [int]$Port = 5088
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dashboardDll = Join-Path $root 'dashboard\CyrodiilMP.Dashboard\bin\Debug\net10.0\CyrodiilMP.Dashboard.dll'
$logDir = Join-Path $root 'research\dashboard-runtime'
$outLog = Join-Path $logDir 'dashboard.out.log'
$errLog = Join-Path $logDir 'dashboard.err.log'
$runner = Join-Path $logDir 'dashboard-runner.cmd'

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$env:CYRODIILMP_ROOT = $root
$env:CYRODIILMP_DASHBOARD_URL = "http://127.0.0.1:$Port"
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

function Test-DashboardReady {
    param([int]$DashboardPort)

    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$DashboardPort/api/state" -UseBasicParsing -TimeoutSec 1
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

if (-not (Test-Path -LiteralPath $dashboardDll -PathType Leaf)) {
    throw "Dashboard is not built yet. Run scripts\run-dashboard.cmd once or build the dashboard project."
}

$existing = Test-DashboardReady -DashboardPort $Port
if ($existing) {
    Write-Host "Dashboard already appears to be listening on http://127.0.0.1:$Port"
    return
}

@(
    '@echo off'
    "set `"CYRODIILMP_ROOT=$root`""
    "set `"CYRODIILMP_DASHBOARD_URL=http://127.0.0.1:$Port`""
    "set `"DOTNET_CLI_HOME=$env:DOTNET_CLI_HOME`""
    "set `"APPDATA=$env:APPDATA`""
    'set "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"'
    "cd /d `"$root`""
    "dotnet `"$dashboardDll`" > `"$outLog`" 2> `"$errLog`""
) | Set-Content -LiteralPath $runner -Encoding ASCII

Start-Process -FilePath $runner -WindowStyle Hidden | Out-Null

for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-DashboardReady -DashboardPort $Port) {
        break
    }
}

if (-not (Test-DashboardReady -DashboardPort $Port)) {
    throw "Dashboard did not start on port $Port. See $errLog"
}

$process = Get-CimInstance Win32_Process -Filter "Name = 'dotnet.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*CyrodiilMP.Dashboard.dll*" } |
    Select-Object -First 1

if ($process) {
    Set-Content -LiteralPath (Join-Path $logDir 'dashboard.pid') -Value $process.ProcessId -Encoding UTF8
}

Write-Host "Started CyrodiilMP dashboard on http://127.0.0.1:$Port"
if ($process) {
    Write-Host "PID: $($process.ProcessId)"
}
Write-Host "Logs: $logDir"
