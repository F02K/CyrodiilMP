param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$nativeRoot  = Join-Path $projectRoot 'native'
$preset      = $Configuration.ToLower()

Write-Host "Building CyrodiilMP native plugin ($Configuration)..."

# Configure
Write-Host ''
Write-Host "cmake --preset $preset"
cmake --preset $preset --log-level=WARNING
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

# Build
Write-Host ''
Write-Host "cmake --build build/$preset --config $Configuration"
cmake --build "$nativeRoot/build/$preset" --config $Configuration
if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)" }

$dllPath = Join-Path $projectRoot "game-plugin\UE4SS\Mods\CyrodiilMP.GameHost\dlls\main.dll"
if (Test-Path -LiteralPath $dllPath -PathType Leaf) {
    Write-Host ''
    Write-Host "Build succeeded: $dllPath"
} else {
    Write-Warning "Build finished but main.dll was not found at $dllPath"
}
