param(
    [string]$Configuration = 'Release',
    [string]$RuntimeIdentifier = 'win-x64',
    [switch]$SelfContained
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$project = Join-Path $root 'client\CyrodiilMP.ClientBridge\CyrodiilMP.ClientBridge.csproj'
$output = Join-Path $root 'artifacts\publish\client-bridge'

$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

$selfContainedValue = if ($SelfContained) { 'true' } else { 'false' }

dotnet publish $project `
    --configuration $Configuration `
    --runtime $RuntimeIdentifier `
    --self-contained $selfContainedValue `
    --output $output

Write-Host "Published CyrodiilMP client bridge:"
Write-Host $output
