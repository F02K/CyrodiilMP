param(
    [string]$Configuration = 'Release',
    [string]$BuildDirectory = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ue4ssRoot = Join-Path $projectRoot 'RE-UE4SS'

if (-not $BuildDirectory) {
    $BuildDirectory = Join-Path $ue4ssRoot 'build\cyrodiilmp'
}

$unrealPseudoRoot = Join-Path $ue4ssRoot 'deps\first\Unreal'
if (-not (Test-Path -LiteralPath (Join-Path $unrealPseudoRoot 'CMakeLists.txt') -PathType Leaf)) {
    throw @"
RE-UE4SS is missing deps\first\Unreal.

The nested submodule now expects an accessible F02K-owned UEPseudo checkout.
Create or grant access to that fork, then run:
  git -C RE-UE4SS submodule sync --recursive
  git -C RE-UE4SS submodule update --init --recursive
"@
}

Write-Host "Configuring RE-UE4SS -> $BuildDirectory"
cmake -S $ue4ssRoot -B $BuildDirectory -G "Visual Studio 17 2022" -A x64
if ($LASTEXITCODE -ne 0) {
    throw "UE4SS CMake configure failed (exit $LASTEXITCODE)"
}

Write-Host "Building RE-UE4SS ($Configuration)"
cmake --build $BuildDirectory --config $Configuration --target UE4SS
if ($LASTEXITCODE -ne 0) {
    throw "UE4SS build failed (exit $LASTEXITCODE)"
}

$ue4ssDll = Get-ChildItem -LiteralPath $BuildDirectory -Recurse -Filter 'UE4SS.dll' -File | Select-Object -First 1
$proxyDll = Get-ChildItem -LiteralPath $BuildDirectory -Recurse -Filter 'dwmapi.dll' -File | Select-Object -First 1

if (-not $ue4ssDll) {
    throw "UE4SS build completed but UE4SS.dll was not found under $BuildDirectory"
}

if (-not $proxyDll) {
    throw "UE4SS build completed but dwmapi.dll was not found under $BuildDirectory"
}

Write-Host ''
Write-Host "UE4SS.dll: $($ue4ssDll.FullName)"
Write-Host "dwmapi.dll: $($proxyDll.FullName)"
