param(
    [string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$projects = @(
    'shared\CyrodiilMP.Protocol\CyrodiilMP.Protocol.csproj',
    'server\CyrodiilMP.Server\CyrodiilMP.Server.csproj',
    'dashboard\CyrodiilMP.Dashboard\CyrodiilMP.Dashboard.csproj'
)

$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:APPDATA = Join-Path $root '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

foreach ($relativeProject in $projects) {
    $project = Join-Path $root $relativeProject
    if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
        throw "Project file not found: $project"
    }
}

foreach ($relativeProject in $projects) {
    $project = Join-Path $root $relativeProject
    Write-Host ""
    Write-Host "==> Restoring $relativeProject"
    dotnet restore $project
}

foreach ($relativeProject in $projects) {
    $project = Join-Path $root $relativeProject
    Write-Host ""
    Write-Host "==> Building $relativeProject"
    dotnet build $project --configuration $Configuration --no-restore
}
