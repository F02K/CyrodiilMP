param(
    [switch]$WriteReport
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

$folders = @(
    [PSCustomObject]@{ Path = 'server'; Category = 'active-source'; Note = 'Dedicated server prototype.' },
    [PSCustomObject]@{ Path = 'shared'; Category = 'active-source'; Note = 'Shared protocol contracts.' },
    [PSCustomObject]@{ Path = 'native'; Category = 'active-source'; Note = 'Standalone runtime, launcher, native GameClient, optional UE4SS C++ work.' },
    [PSCustomObject]@{ Path = 'client'; Category = 'active-source/transitional'; Note = 'Managed bridge for early smoke tests.' },
    [PSCustomObject]@{ Path = 'dashboard'; Category = 'active-source/tooling'; Note = 'Local research dashboard.' },
    [PSCustomObject]@{ Path = 'game-plugin'; Category = 'active-source/research'; Note = 'UE4SS Lua research/bootstrap mods.' },
    [PSCustomObject]@{ Path = 'scripts'; Category = 'active-source/tooling'; Note = 'Reusable developer commands.' },
    [PSCustomObject]@{ Path = 'build'; Category = 'active-source/tooling'; Note = 'Build/publish helper scripts. Not generated output.' },
    [PSCustomObject]@{ Path = 'docs'; Category = 'active-source/docs'; Note = 'Project documentation.' },
    [PSCustomObject]@{ Path = 'tests'; Category = 'active-source/probes'; Note = 'Probe/test executables.' },
    [PSCustomObject]@{ Path = 'research'; Category = 'research-workspace'; Note = 'Notes and generated research evidence.' },
    [PSCustomObject]@{ Path = 'artifacts'; Category = 'generated'; Note = 'Compiled/published outputs. Safe to regenerate.' },
    [PSCustomObject]@{ Path = 'native/build'; Category = 'generated'; Note = 'CMake build tree. Safe to regenerate.' },
    [PSCustomObject]@{ Path = '.dotnet-home'; Category = 'local-cache'; Note = 'Project-local .NET/NuGet cache.' },
    [PSCustomObject]@{ Path = 'tools'; Category = 'local-third-party'; Note = 'Downloaded tools such as FModel/UE4SS.' },
    [PSCustomObject]@{ Path = 'vendor'; Category = 'local-third-party/experiments'; Note = 'Dependency/template checkouts.' },
    [PSCustomObject]@{ Path = '.claude'; Category = 'local-tooling'; Note = 'Local assistant/tool metadata.' }
)

function Get-DirectorySize {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0
    }

    $sum = 0L
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sum += $_.Length
    }

    return $sum
}

$rows = foreach ($folder in $folders) {
    $fullPath = Join-Path $projectRoot $folder.Path
    $exists = Test-Path -LiteralPath $fullPath -PathType Container
    $size = if ($exists) { Get-DirectorySize -Path $fullPath } else { 0 }

    [PSCustomObject]@{
        Path = $folder.Path
        Exists = $exists
        Category = $folder.Category
        SizeMB = [Math]::Round($size / 1MB, 2)
        Note = $folder.Note
    }
}

$lines = @()
$lines += '# CyrodiilMP Repository Layout Audit'
$lines += ''
$lines += "- Created: $((Get-Date).ToString('o'))"
$lines += ('- Root: `{0}`' -f $projectRoot)
$lines += ''
$lines += '| Path | Exists | Category | Size MB | Note |'
$lines += '| --- | --- | --- | ---: | --- |'
foreach ($row in $rows) {
    $lines += ('| `{0}` | {1} | {2} | {3} | {4} |' -f $row.Path, $row.Exists, $row.Category, $row.SizeMB, $row.Note)
}
$lines += ''
$lines += '## Guidance'
$lines += ''
$lines += '- Treat `active-source` folders as code/docs that need deliberate refactors.'
$lines += '- Treat `generated`, `local-cache`, and `local-third-party` folders as reproducible local state.'
$lines += '- Treat `research-workspace` as evidence: keep good notes, ignore bulky generated output.'

$lines | ForEach-Object { Write-Host $_ }

if ($WriteReport) {
    $outputDir = Join-Path $projectRoot 'research\repo-audits'
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $outputPath = Join-Path $outputDir "repo-layout-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $lines | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Host ''
    Write-Host "Wrote: $outputPath"
}
