Set-StrictMode -Version Latest

function Get-CyrodiilMPRoot {
    $modulePath = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $modulePath '..')).Path
}

function Get-CyrodiilMPResearchPath {
    param(
        [string]$Name = 'quick-scans'
    )

    $root = Get-CyrodiilMPRoot
    $path = Join-Path $root "research\$Name"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Get-CyrodiilMPDefaultGameCandidates {
    $names = @(
        'Oblivion Remastered',
        'The Elder Scrolls IV Oblivion Remastered',
        'The Elder Scrolls IV - Oblivion Remastered'
    )

    $roots = @()

    if ($env:CYRODIILMP_GAME_DIR) {
        $roots += $env:CYRODIILMP_GAME_DIR
    }

    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $letter = $drive.Root.TrimEnd('\')
        $roots += Join-Path $letter 'SteamLibrary\steamapps\common'
        $roots += Join-Path $letter 'Program Files (x86)\Steam\steamapps\common'
        $roots += Join-Path $letter 'Program Files\Steam\steamapps\common'
        $roots += Join-Path $letter 'XboxGames'
        $roots += Join-Path $letter 'Program Files\Epic Games'
        $roots += Join-Path $letter 'Epic Games'
    }

    foreach ($root in ($roots | Select-Object -Unique)) {
        foreach ($name in $names) {
            Join-Path $root $name
        }
    }
}

function Resolve-CyrodiilMPGamePath {
    param(
        [string]$GamePath
    )

    if ($GamePath) {
        if (-not (Test-Path -LiteralPath $GamePath -PathType Container)) {
            throw "GamePath does not exist or is not a directory: $GamePath"
        }

        return (Resolve-Path -LiteralPath $GamePath).Path
    }

    foreach ($candidate in Get-CyrodiilMPDefaultGameCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Could not find Oblivion Remastered automatically. Pass -GamePath or set CYRODIILMP_GAME_DIR."
}

function Find-CyrodiilMPUnrealFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $resolved = Resolve-CyrodiilMPGamePath -GamePath $GamePath
    $extensions = @('*.pak', '*.utoc', '*.ucas', '*.usmap', '*.uproject', '*.ini', '*.exe', '*.dll')

    foreach ($extension in $extensions) {
        Get-ChildItem -LiteralPath $resolved -Recurse -File -Filter $extension -ErrorAction SilentlyContinue |
            Select-Object @{
                Name = 'Kind'
                Expression = { $_.Extension.TrimStart('.').ToLowerInvariant() }
            }, @{
                Name = 'Path'
                Expression = { $_.FullName }
            }, @{
                Name = 'RelativePath'
                Expression = { $_.FullName.Substring($resolved.Length).TrimStart('\') }
            }, @{
                Name = 'SizeBytes'
                Expression = { $_.Length }
            }, LastWriteTime
    }
}

function New-CyrodiilMPGameInventory {
    param(
        [string]$GamePath,
        [string]$OutputDirectory
    )

    $resolved = Resolve-CyrodiilMPGamePath -GamePath $GamePath
    if (-not $OutputDirectory) {
        $OutputDirectory = Get-CyrodiilMPResearchPath -Name 'game-inventory'
    }

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $OutputDirectory "inventory-$stamp.json"
    $markdownPath = Join-Path $OutputDirectory "inventory-$stamp.md"

    $files = @(Find-CyrodiilMPUnrealFiles -GamePath $resolved)
    $groups = @($files | Group-Object Kind | Sort-Object Name)
    $exeFiles = @($files | Where-Object { $_.Kind -eq 'exe' } | Sort-Object RelativePath)
    $packageFiles = @($files | Where-Object { $_.Kind -in @('pak', 'utoc', 'ucas') } | Sort-Object RelativePath)

    $inventory = [PSCustomObject]@{
        CreatedAt = (Get-Date).ToString('o')
        GamePath = $resolved
        FileCount = $files.Count
        Groups = @($groups | ForEach-Object {
            [PSCustomObject]@{
                Kind = $_.Name
                Count = $_.Count
                TotalSizeBytes = ($_.Group | Measure-Object SizeBytes -Sum).Sum
            }
        })
        Files = $files
    }

    $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $lines = @()
    $lines += '# Oblivion Remastered Inventory'
    $lines += ''
    $lines += "- Created: $($inventory.CreatedAt)"
    $lines += ('- Game path: `{0}`' -f $resolved)
    $lines += "- Total indexed files: $($files.Count)"
    $lines += ''
    $lines += '## File Groups'
    $lines += ''
    foreach ($group in $inventory.Groups) {
        $mb = if ($group.TotalSizeBytes) { [Math]::Round($group.TotalSizeBytes / 1MB, 2) } else { 0 }
        $lines += ('- `{0}`: {1} files, {2} MB' -f $group.Kind, $group.Count, $mb)
    }

    $lines += ''
    $lines += '## Executables'
    $lines += ''
    foreach ($file in $exeFiles) {
        $lines += ('- `{0}`' -f $file.RelativePath)
    }

    $lines += ''
    $lines += '## UE Package Files'
    $lines += ''
    foreach ($file in $packageFiles) {
        $mb = [Math]::Round($file.SizeBytes / 1MB, 2)
        $lines += ('- `{0}` - {1} MB' -f $file.RelativePath, $mb)
    }

    $lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

    [PSCustomObject]@{
        GamePath = $resolved
        Json = $jsonPath
        Markdown = $markdownPath
        FileCount = $files.Count
        PackageFileCount = $packageFiles.Count
    }
}

function Open-CyrodiilMPFModel {
    $root = Get-CyrodiilMPRoot
    $fmodel = Join-Path $root 'tools\FModel\current\FModel.exe'

    if (-not (Test-Path -LiteralPath $fmodel -PathType Leaf)) {
        throw "FModel is not installed at $fmodel"
    }

    Start-Process -FilePath $fmodel -WorkingDirectory (Split-Path -Parent $fmodel) | Out-Null
}

function New-CyrodiilMPResearchRun {
    param(
        [string]$Name = 'manual'
    )

    $safeName = $Name -replace '[^a-zA-Z0-9._-]', '-'
    $root = Get-CyrodiilMPResearchPath -Name 'runs'
    $runPath = Join-Path $root "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$safeName"

    New-Item -ItemType Directory -Path $runPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $runPath 'screenshots') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $runPath 'logs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $runPath 'dumps') -Force | Out-Null

    $notes = Join-Path $runPath 'notes.md'
    @(
        '# Research Run'
        ''
        "- Created: $((Get-Date).ToString('o'))"
        "- Name: $Name"
        ''
        '## Goal'
        ''
        '- '
        ''
        '## Findings'
        ''
        '- '
    ) | Set-Content -LiteralPath $notes -Encoding UTF8

    [PSCustomObject]@{
        Path = $runPath
        Notes = $notes
    }
}

Export-ModuleMember -Function @(
    'Get-CyrodiilMPRoot',
    'Get-CyrodiilMPResearchPath',
    'Get-CyrodiilMPDefaultGameCandidates',
    'Resolve-CyrodiilMPGamePath',
    'Find-CyrodiilMPUnrealFiles',
    'New-CyrodiilMPGameInventory',
    'Open-CyrodiilMPFModel',
    'New-CyrodiilMPResearchRun'
)
