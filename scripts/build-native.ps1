param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$Ue4ssRoot,
    [switch]$BuildUe4ssGameHost
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$nativeRoot  = Join-Path $projectRoot 'native'
$preset      = $Configuration.ToLower()
$nativeBuildRoot = Join-Path $nativeRoot "build\$preset"

Write-Host "Building CyrodiilMP native plugin ($Configuration)..."

if (-not [string]::IsNullOrWhiteSpace($Ue4ssRoot)) {
    $env:UE4SS_ROOT = (Resolve-Path -LiteralPath $Ue4ssRoot).Path
}

Push-Location $nativeRoot
try {
    if ((Test-Path -LiteralPath $nativeBuildRoot -PathType Container) -and -not $BuildUe4ssGameHost) {
        $resolvedBuildRoot = (Resolve-Path -LiteralPath $nativeBuildRoot).Path
        $resolvedNativeRoot = (Resolve-Path -LiteralPath $nativeRoot).Path
        if (-not $resolvedBuildRoot.StartsWith($resolvedNativeRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove unexpected native build folder: $resolvedBuildRoot"
        }

        Write-Host "Cleaning native preset cache for standalone build: $resolvedBuildRoot"
        Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
    }

    # Configure
    Write-Host ''
    Write-Host "cmake --preset $preset"
    $gameHostValue = if ($BuildUe4ssGameHost) { 'ON' } else { 'OFF' }
    cmake --preset $preset --log-level=WARNING "-DCYRODIILMP_BUILD_UE4SS_GAMEHOST=$gameHostValue"
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

    # Build
    Write-Host ''
    Write-Host "cmake --build --preset $preset --config $Configuration"
    cmake --build --preset $preset --config $Configuration
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)" }
}
finally {
    Pop-Location
}

$dllPath = Join-Path $projectRoot "game-plugin\UE4SS\Mods\CyrodiilMP.GameHost\dlls\main.dll"
$gameClientDll = Join-Path $projectRoot "artifacts\native\$Configuration\GameClient\CyrodiilMP.GameClient.dll"
$gameClientHost = Join-Path $projectRoot "artifacts\native\$Configuration\GameClient\CyrodiilMP.GameClient.Host.exe"
$standaloneBootstrapDll = Join-Path $projectRoot "artifacts\native\$Configuration\Standalone\CyrodiilMP.Bootstrap.dll"
$standaloneLauncherExe = Join-Path $projectRoot "artifacts\native\$Configuration\Standalone\CyrodiilMP.Launcher.exe"

if (Test-Path -LiteralPath $gameClientDll -PathType Leaf) {
    Write-Host ''
    Write-Host "GameClient build succeeded: $gameClientDll"
    Write-Host "GameClient host: $gameClientHost"
} else {
    Write-Warning "Build finished but CyrodiilMP.GameClient.dll was not found at $gameClientDll"
}

if ((Test-Path -LiteralPath $standaloneBootstrapDll -PathType Leaf) -and (Test-Path -LiteralPath $standaloneLauncherExe -PathType Leaf)) {
    Write-Host ''
    Write-Host "Standalone bootstrap build succeeded: $standaloneBootstrapDll"
    Write-Host "Standalone launcher: $standaloneLauncherExe"
    Write-Host 'Install it with:'
    Write-Host "  .\scripts\install-standalone-loader.ps1 -Configuration $Configuration"
} else {
    Write-Warning "Build finished but standalone loader outputs were not found under artifacts\native\$Configuration\Standalone"
}

if ($BuildUe4ssGameHost) {
    if (Test-Path -LiteralPath $dllPath -PathType Leaf) {
        Write-Host "UE4SS GameHost build succeeded: $dllPath"
    } else {
        Write-Warning "Build finished but main.dll was not found at $dllPath"
    }
}
