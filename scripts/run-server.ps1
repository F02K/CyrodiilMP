param(
    [int]$Port = 27015
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$serverProject = Join-Path $root 'server\CyrodiilMP.Server\CyrodiilMP.Server.csproj'

$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

dotnet run --project $serverProject --no-restore -- --port $Port
