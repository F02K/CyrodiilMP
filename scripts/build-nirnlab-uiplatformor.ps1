param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$VcpkgRoot = $env:VCPKG_ROOT,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$sourceRoot = Join-Path $projectRoot 'vendor\NirnLabUIPlatformOR'
$preset = $Configuration.ToLower()
$buildRoot = Join-Path $projectRoot "artifacts\build\nirnlab-uiplatformor\$preset"
$outputRoot = Join-Path $projectRoot "artifacts\native\$Configuration"
$packageRoot = Join-Path $outputRoot 'NirnLabUIPlatformOR'

if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'CMakeLists.txt') -PathType Leaf)) {
    throw "NirnLabUIPlatformOR source was not found at $sourceRoot. Run git submodule update --init --recursive."
}

if ([string]::IsNullOrWhiteSpace($VcpkgRoot)) {
    throw 'VCPKG_ROOT is not set. Pass -VcpkgRoot or set the VCPKG_ROOT environment variable before building NirnLabUIPlatformOR.'
}

if (-not (Test-Path -LiteralPath (Join-Path $VcpkgRoot 'scripts\buildsystems\vcpkg.cmake') -PathType Leaf)) {
    throw "Vcpkg toolchain was not found under $VcpkgRoot"
}

if ($Clean -and (Test-Path -LiteralPath $buildRoot -PathType Container)) {
    $resolvedBuildRoot = (Resolve-Path -LiteralPath $buildRoot).Path
    $resolvedArtifactsRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot 'artifacts')).Path
    if (-not $resolvedBuildRoot.StartsWith($resolvedArtifactsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected build folder: $resolvedBuildRoot"
    }

    Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

Write-Host "Building NirnLabUIPlatformOR ($Configuration)..."
Write-Host "Source:  $sourceRoot"
Write-Host "Build:   $buildRoot"
Write-Host "Package: $packageRoot"
Write-Host ''

cmake `
    -S $sourceRoot `
    -B $buildRoot `
    -A x64 `
    "-DVCPKG_ROOT=$VcpkgRoot" `
    "-DOUTPUT_PATH=$outputRoot" `
    "-DOBLIVION_PLUGIN_REL_PATH=NirnLabUIPlatformOR" `
    "-DNL_UI_REL_PATH=NirnLabUIPlatformOR"
if ($LASTEXITCODE -ne 0) {
    throw "NirnLabUIPlatformOR CMake configure failed (exit $LASTEXITCODE)"
}

cmake --build $buildRoot --config $Configuration --parallel
if ($LASTEXITCODE -ne 0) {
    throw "NirnLabUIPlatformOR build failed (exit $LASTEXITCODE)"
}

$dllPath = Join-Path $packageRoot 'NirnLabUIPlatform.dll'
if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
    throw "NirnLabUIPlatformOR build finished but $dllPath was not produced."
}

Write-Host ''
Write-Host "NirnLabUIPlatformOR build succeeded: $dllPath"
