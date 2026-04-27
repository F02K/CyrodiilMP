param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 27015,
    [string]$Name = 'ProbePlayer'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$probeProject = Join-Path $root 'tests\CyrodiilMP.NetProbe\CyrodiilMP.NetProbe.csproj'

$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

dotnet run --project $probeProject --no-restore -- --host $HostName --port $Port --name $Name
