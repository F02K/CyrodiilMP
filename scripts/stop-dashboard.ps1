$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$pidFile = Join-Path $root 'research\dashboard-runtime\dashboard.pid'

if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) {
    Write-Host 'No dashboard PID file found.'
    return
}

$dashboardPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
if (-not $dashboardPid) {
    Write-Host 'Dashboard PID file is empty.'
    return
}

$process = Get-Process -Id ([int]$dashboardPid) -ErrorAction SilentlyContinue
if (-not $process) {
    Remove-Item -LiteralPath $pidFile -Force
    Write-Host "Dashboard process $dashboardPid is not running. Removed stale PID file."
    return
}

Stop-Process -Id $process.Id -Force
Remove-Item -LiteralPath $pidFile -Force
Write-Host "Stopped CyrodiilMP dashboard process $($process.Id)."
