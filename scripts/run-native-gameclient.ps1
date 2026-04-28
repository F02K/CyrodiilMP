param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 27016,
    [string]$Name = 'NativeManual',
    [string]$Reason = 'manual-native-test',
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$hostExe = Join-Path $root "artifacts\native\$Configuration\GameClient\CyrodiilMP.GameClient.Host.exe"
$logPath = Join-Path $root 'research\net-smoke\native-gameclient.log'

if (-not (Test-Path -LiteralPath $hostExe -PathType Leaf)) {
    throw "Native GameClient host not found: $hostExe. Run scripts\build-native.cmd first."
}

New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null

& $hostExe --host $HostName --port $Port --name $Name --reason $Reason --log $logPath
if ($LASTEXITCODE -ne 0) {
    throw "Native GameClient host exited with $LASTEXITCODE"
}

Write-Host "Native GameClient log: $logPath"
