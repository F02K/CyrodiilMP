param(
    [string]$GamePath,
    [string]$Name = 'runtime'
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$sourcePath = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\CyrodiilMP_RuntimeDumps'
$menuProbePath = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64\CyrodiilMP_MenuProbe'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
    throw "Runtime dump folder does not exist yet: $sourcePath"
}

$safeName = $Name -replace '[^a-zA-Z0-9._-]', '-'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$targetPath = Join-Path $projectRoot "research\runtime-dumps\$stamp-$safeName"
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

$allowedExtensions = @('.csv', '.md', '.txt', '.log', '.json')
$sources = @($sourcePath)
if (Test-Path -LiteralPath $menuProbePath -PathType Container) {
    $sources += $menuProbePath
}

$files = @()
foreach ($source in $sources) {
    $files += @(Get-ChildItem -LiteralPath $source -File -ErrorAction SilentlyContinue | Where-Object {
        $allowedExtensions -contains $_.Extension.ToLowerInvariant()
    })
}

foreach ($file in $files) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $targetPath $file.Name) -Force
}

$sourceLines = @($sources | ForEach-Object { '- `{0}`' -f $_ })
$fileLines = @($files | Sort-Object Name | ForEach-Object { '- `{0}` ({1} bytes)' -f $_.Name, $_.Length })
$reportLines = @(
    '# Runtime Dump Collection'
    ''
    "- Created: $((Get-Date).ToString('o'))"
    ''
    '## Sources'
    ''
)
$reportLines += $sourceLines
$reportLines += @(
    ''
    "- Files copied: $($files.Count)"
    ''
    '## Files'
    ''
)
$reportLines += $fileLines

$reportPath = Join-Path $targetPath 'collection-report.md'
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host 'Runtime dump collection complete.'
Write-Host "Output: $targetPath"
Write-Host "Report: $reportPath"
Write-Host ''
Get-Content -LiteralPath $reportPath | ForEach-Object { Write-Host $_ }
