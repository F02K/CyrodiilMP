param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 27015,
    [string]$Name = 'ManualBridge',
    [string]$Reason = 'manual-script',
    [int]$TimeoutMs = 1800
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$project = Join-Path $root 'client\CyrodiilMP.ClientBridge\CyrodiilMP.ClientBridge.csproj'
$resultPath = Join-Path $root 'research\net-smoke\client-bridge-result.json'

$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null

dotnet run --project $project -- `
    --host $HostName `
    --port $Port `
    --name $Name `
    --reason $Reason `
    --timeout-ms $TimeoutMs `
    --out $resultPath

Write-Host "Result: $resultPath"
