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
    $projectRoot = Get-CyrodiilMPRoot
    $configuredPathFile = Join-Path $projectRoot 'game-path.txt'

    if ($env:CYRODIILMP_GAME_DIR) {
        $roots += $env:CYRODIILMP_GAME_DIR
    }

    if (Test-Path -LiteralPath $configuredPathFile -PathType Leaf) {
        $configuredPath = (Get-Content -LiteralPath $configuredPathFile -Raw).Trim()
        if ($configuredPath) {
            $roots += $configuredPath
        }
    }

    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $letter = $drive.Root.TrimEnd('\')
        $roots += Join-Path $letter 'Steam\steamapps\common'
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

    throw "Could not find Oblivion Remastered automatically. Pass -GamePath, set CYRODIILMP_GAME_DIR, or put the install path in game-path.txt."
}

function Find-CyrodiilMPUnrealFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $resolved = Resolve-CyrodiilMPGamePath -GamePath $GamePath
    $extensions = @(
        '*.pak', '*.utoc', '*.ucas', '*.usmap', '*.uproject',
        '*.bsa', '*.esm', '*.esp', '*.esl',
        '*.ini', '*.json', '*.exe', '*.dll'
    )

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
    if ($inventory.Groups.Count -eq 0) {
        $lines += '- No matching files were found.'
    }
    else {
        foreach ($group in $inventory.Groups) {
            $mb = if ($group.TotalSizeBytes) { [Math]::Round($group.TotalSizeBytes / 1MB, 2) } else { 0 }
            $lines += ('- `{0}`: {1} files, {2} MB' -f $group.Kind, $group.Count, $mb)
        }
    }

    $lines += ''
    $lines += '## Executables'
    $lines += ''
    if ($exeFiles.Count -eq 0) {
        $lines += '- No executables found.'
    }
    else {
        foreach ($file in $exeFiles) {
            $lines += ('- `{0}`' -f $file.RelativePath)
        }
    }

    $lines += ''
    $lines += '## UE Package Files'
    $lines += ''
    if ($packageFiles.Count -eq 0) {
        $lines += '- No `.pak`, `.utoc`, or `.ucas` files found. Check that `-GamePath` points at the actual Oblivion Remastered install folder.'
    }
    else {
        foreach ($file in $packageFiles) {
            $mb = [Math]::Round($file.SizeBytes / 1MB, 2)
            $lines += ('- `{0}` - {1} MB' -f $file.RelativePath, $mb)
        }
    }

    $lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

    [PSCustomObject]@{
        GamePath = $resolved
        Json = $jsonPath
        Markdown = $markdownPath
        FileCount = $files.Count
        PackageFileCount = $packageFiles.Count
        ExecutableFileCount = $exeFiles.Count
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

    $createdAt = (Get-Date).ToString('o')
    $notes = Join-Path $runPath 'notes.md'
    @(
        '# Research Run'
        ''
        "- Created: $createdAt"
        "- Name: $Name"
        ''
        '## Goal'
        ''
        '- Write the specific question for this pass here.'
        ''
        '## Commands Or Tools Used'
        ''
        '- Example: FModel package browsing'
        '- Example: quick-scan.cmd output review'
        ''
        '## Findings'
        ''
        '- Add observations here.'
        ''
        '## Next Actions'
        ''
        '- Add the next thing to verify here.'
    ) | Set-Content -LiteralPath $notes -Encoding UTF8

    $readme = Join-Path $runPath 'README.md'
    @(
        '# CyrodiilMP Research Run'
        ''
        "Created: $createdAt"
        ''
        'This folder is for one focused research pass.'
        ''
        '## Folder Purpose'
        ''
        '- `notes.md` - human-written observations and next steps.'
        '- `logs/` - text logs copied from tools or the game.'
        '- `dumps/` - generated SDK dumps, object lists, or structured output.'
        '- `screenshots/` - screenshots used to document findings.'
        ''
        'Empty subfolders are expected until you place data in them.'
    ) | Set-Content -LiteralPath $readme -Encoding UTF8

    $status = Join-Path $runPath 'status.txt'
    @(
        'CyrodiilMP research run created successfully.'
        "Name: $Name"
        "Created: $createdAt"
        "Path: $runPath"
        ''
        'Next: open notes.md and record what you are testing.'
    ) | Set-Content -LiteralPath $status -Encoding UTF8

    [PSCustomObject]@{
        Path = $runPath
        Notes = $notes
        Readme = $readme
        Status = $status
    }
}

function ConvertTo-CyrodiilMPRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path.StartsWith($RootPath, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($RootPath.Length).TrimStart('\')
    }

    return $Path
}

function Get-CyrodiilMPFileHeadHex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$ByteCount = 16
    )

    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buffer = New-Object byte[] $ByteCount
            $read = $stream.Read($buffer, 0, $ByteCount)
            if ($read -le 0) {
                return ''
            }

            return [Convert]::ToHexString($buffer[0..($read - 1)])
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return ''
    }
}

function Get-CyrodiilMPVersionInfo {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($File.FullName)
    [PSCustomObject]@{
        RelativePath = ConvertTo-CyrodiilMPRelativePath -RootPath $GamePath -Path $File.FullName
        SizeBytes = $File.Length
        LastWriteTime = $File.LastWriteTime.ToString('o')
        ProductName = $info.ProductName
        ProductVersion = $info.ProductVersion
        FileDescription = $info.FileDescription
        FileVersion = $info.FileVersion
        CompanyName = $info.CompanyName
        Sha256 = if ($File.Length -le 512MB) { (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash } else { '' }
        HeadHex = Get-CyrodiilMPFileHeadHex -Path $File.FullName
    }
}

function Get-CyrodiilMPIniSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $sections = @()
    $lineCount = 0
    try {
        foreach ($line in [System.IO.File]::ReadLines($File.FullName)) {
            $lineCount++
            if ($line -match '^\s*\[(.+?)\]\s*$') {
                $sections += $Matches[1]
            }
        }
    }
    catch {
        $sections = @('unreadable')
    }

    [PSCustomObject]@{
        RelativePath = ConvertTo-CyrodiilMPRelativePath -RootPath $GamePath -Path $File.FullName
        SizeBytes = $File.Length
        LastWriteTime = $File.LastWriteTime.ToString('o')
        LineCount = $lineCount
        SectionCount = @($sections | Select-Object -Unique).Count
        Sections = (@($sections | Select-Object -Unique | Select-Object -First 40) -join ', ')
    }
}

function Get-CyrodiilMPPackageSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $relativePath = ConvertTo-CyrodiilMPRelativePath -RootPath $GamePath -Path $File.FullName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $directory = $File.DirectoryName

    [PSCustomObject]@{
        RelativePath = $relativePath
        Kind = $File.Extension.TrimStart('.').ToLowerInvariant()
        BaseName = $baseName
        SizeBytes = $File.Length
        SizeMB = [Math]::Round($File.Length / 1MB, 2)
        LastWriteTime = $File.LastWriteTime.ToString('o')
        HeadHex = Get-CyrodiilMPFileHeadHex -Path $File.FullName
        HasPak = Test-Path -LiteralPath (Join-Path $directory "$baseName.pak") -PathType Leaf
        HasUtoc = Test-Path -LiteralPath (Join-Path $directory "$baseName.utoc") -PathType Leaf
        HasUcas = Test-Path -LiteralPath (Join-Path $directory "$baseName.ucas") -PathType Leaf
    }
}

function Get-CyrodiilMPSteamManifestClues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $leaf = Split-Path -Leaf $GamePath
    $steamAppsRoots = @()

    if ($GamePath -match '^(.*\\steamapps)\\common\\') {
        $steamAppsRoots += $Matches[1]
    }

    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $letter = $drive.Root.TrimEnd('\')
        $steamAppsRoots += Join-Path $letter 'SteamLibrary\steamapps'
        $steamAppsRoots += Join-Path $letter 'Program Files (x86)\Steam\steamapps'
        $steamAppsRoots += Join-Path $letter 'Program Files\Steam\steamapps'
    }

    foreach ($root in ($steamAppsRoots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $text) {
                return
            }

            $name = if ($text -match '"name"\s+"([^"]+)"') { $Matches[1] } else { '' }
            $installDir = if ($text -match '"installdir"\s+"([^"]+)"') { $Matches[1] } else { '' }
            $appId = if ($text -match '"appid"\s+"([^"]+)"') { $Matches[1] } else { '' }

            if ($name -match 'Oblivion' -or $installDir -match 'Oblivion' -or $installDir -eq $leaf) {
                [PSCustomObject]@{
                    AppId = $appId
                    Name = $name
                    InstallDir = $installDir
                    ManifestPath = $_.FullName
                    LastWriteTime = $_.LastWriteTime.ToString('o')
                }
            }
        }
    }
}

function Get-CyrodiilMPLayoutSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GamePath
    )

    $checks = @(
        'Content',
        'Content\Paks',
        'Engine',
        'Engine\Binaries',
        'Engine\Binaries\ThirdParty',
        'Binaries',
        'Binaries\Win64',
        'OblivionRemastered\Content',
        'OblivionRemastered\Content\Paks',
        'OblivionRemastered\Binaries\Win64'
    )

    foreach ($check in $checks) {
        $path = Join-Path $GamePath $check
        [PSCustomObject]@{
            RelativePath = $check
            Exists = Test-Path -LiteralPath $path
        }
    }
}

function New-CyrodiilMPFullResearch {
    param(
        [string]$GamePath,
        [string]$OutputDirectory
    )

    $resolved = Resolve-CyrodiilMPGamePath -GamePath $GamePath
    if (-not $OutputDirectory) {
        $OutputDirectory = Get-CyrodiilMPResearchPath -Name 'full-research'
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runPath = Join-Path $OutputDirectory "research-$stamp"
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null

    $allFiles = @(Get-ChildItem -LiteralPath $resolved -Recurse -File -ErrorAction SilentlyContinue)
    $interestingFiles = @($allFiles | Where-Object {
        $_.Extension.ToLowerInvariant() -in @(
            '.pak', '.utoc', '.ucas', '.usmap', '.uproject',
            '.bsa', '.esm', '.esp', '.esl',
            '.ini', '.exe', '.dll', '.json'
        )
    })
    $packages = @($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -in @('.pak', '.utoc', '.ucas') } | Sort-Object FullName)
    $legacyData = @($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -in @('.bsa', '.esm', '.esp', '.esl') } | Sort-Object FullName)
    $executables = @($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -in @('.exe', '.dll') } | Sort-Object FullName)
    $iniFiles = @($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -eq '.ini' } | Sort-Object FullName)
    $largestFiles = @($allFiles | Sort-Object Length -Descending | Select-Object -First 50)
    $layout = @(Get-CyrodiilMPLayoutSummary -GamePath $resolved)
    $steamManifests = @(Get-CyrodiilMPSteamManifestClues -GamePath $resolved)

    $packageSummaries = @($packages | ForEach-Object { Get-CyrodiilMPPackageSummary -File $_ -GamePath $resolved })
    $legacyDataSummaries = @($legacyData | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = ConvertTo-CyrodiilMPRelativePath -RootPath $resolved -Path $_.FullName
            Kind = $_.Extension.TrimStart('.').ToLowerInvariant()
            SizeBytes = $_.Length
            SizeMB = [Math]::Round($_.Length / 1MB, 2)
            LastWriteTime = $_.LastWriteTime.ToString('o')
            HeadHex = Get-CyrodiilMPFileHeadHex -Path $_.FullName
            Sha256 = if ($_.Length -le 512MB) { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } else { '' }
        }
    })
    $versionSummaries = @($executables | ForEach-Object { Get-CyrodiilMPVersionInfo -File $_ -GamePath $resolved })
    $iniSummaries = @($iniFiles | ForEach-Object { Get-CyrodiilMPIniSummary -File $_ -GamePath $resolved })
    $largestSummaries = @($largestFiles | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = ConvertTo-CyrodiilMPRelativePath -RootPath $resolved -Path $_.FullName
            Kind = $_.Extension.TrimStart('.').ToLowerInvariant()
            SizeBytes = $_.Length
            SizeMB = [Math]::Round($_.Length / 1MB, 2)
            LastWriteTime = $_.LastWriteTime.ToString('o')
        }
    })

    $fileGroups = @($interestingFiles | Group-Object { $_.Extension.TrimStart('.').ToLowerInvariant() } | Sort-Object Name | ForEach-Object {
        [PSCustomObject]@{
            Kind = if ($_.Name) { $_.Name } else { 'no-extension' }
            Count = $_.Count
            TotalSizeBytes = ($_.Group | Measure-Object Length -Sum).Sum
            TotalSizeMB = [Math]::Round((($_.Group | Measure-Object Length -Sum).Sum) / 1MB, 2)
        }
    })

    $summary = [PSCustomObject]@{
        CreatedAt = (Get-Date).ToString('o')
        GamePath = $resolved
        TotalFiles = $allFiles.Count
        InterestingFiles = $interestingFiles.Count
        PackageFiles = $packages.Count
        LegacyDataFiles = $legacyData.Count
        ExecutablesAndDlls = $executables.Count
        IniFiles = $iniFiles.Count
        SteamManifestMatches = $steamManifests.Count
        FileGroups = $fileGroups
        Layout = $layout
        SteamManifests = $steamManifests
    }

    $summaryPath = Join-Path $runPath 'summary.json'
    $reportPath = Join-Path $runPath 'report.md'
    $packagesPath = Join-Path $runPath 'packages.csv'
    $legacyDataPath = Join-Path $runPath 'legacy-data.csv'
    $versionsPath = Join-Path $runPath 'executables-and-dlls.csv'
    $iniPath = Join-Path $runPath 'ini-summary.csv'
    $largestPath = Join-Path $runPath 'largest-files.csv'
    $layoutPath = Join-Path $runPath 'layout.csv'
    $steamPath = Join-Path $runPath 'steam-manifests.csv'

    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Export-CyrodiilMPCsv -Rows $packageSummaries -Path $packagesPath -Columns @(
        'RelativePath', 'Kind', 'BaseName', 'SizeBytes', 'SizeMB', 'LastWriteTime', 'HeadHex', 'HasPak', 'HasUtoc', 'HasUcas'
    )
    Export-CyrodiilMPCsv -Rows $legacyDataSummaries -Path $legacyDataPath -Columns @(
        'RelativePath', 'Kind', 'SizeBytes', 'SizeMB', 'LastWriteTime', 'HeadHex', 'Sha256'
    )
    Export-CyrodiilMPCsv -Rows $versionSummaries -Path $versionsPath -Columns @(
        'RelativePath', 'SizeBytes', 'LastWriteTime', 'ProductName', 'ProductVersion', 'FileDescription', 'FileVersion', 'CompanyName', 'Sha256', 'HeadHex'
    )
    Export-CyrodiilMPCsv -Rows $iniSummaries -Path $iniPath -Columns @(
        'RelativePath', 'SizeBytes', 'LastWriteTime', 'LineCount', 'SectionCount', 'Sections'
    )
    Export-CyrodiilMPCsv -Rows $largestSummaries -Path $largestPath -Columns @(
        'RelativePath', 'Kind', 'SizeBytes', 'SizeMB', 'LastWriteTime'
    )
    Export-CyrodiilMPCsv -Rows $layout -Path $layoutPath -Columns @(
        'RelativePath', 'Exists'
    )
    Export-CyrodiilMPCsv -Rows $steamManifests -Path $steamPath -Columns @(
        'AppId', 'Name', 'InstallDir', 'ManifestPath', 'LastWriteTime'
    )

    $report = @()
    $report += '# CyrodiilMP Full Research Report'
    $report += ''
    $report += "- Created: $($summary.CreatedAt)"
    $report += ('- Game path: `{0}`' -f $resolved)
    $report += "- Total files scanned: $($summary.TotalFiles)"
    $report += "- Interesting files indexed: $($summary.InterestingFiles)"
    $report += "- UE package files: $($summary.PackageFiles)"
    $report += "- Legacy Bethesda data files: $($summary.LegacyDataFiles)"
    $report += "- Executables/DLLs: $($summary.ExecutablesAndDlls)"
    $report += "- INI files: $($summary.IniFiles)"
    $report += "- Steam manifest matches: $($summary.SteamManifestMatches)"
    $report += ''
    $report += '## Files Written'
    $report += ''
    $report += '- `summary.json` - top-level structured summary.'
    $report += '- `packages.csv` - `.pak`, `.utoc`, `.ucas` metadata and companion-file detection.'
    $report += '- `legacy-data.csv` - `.bsa`, `.esm`, `.esp`, `.esl` metadata if present.'
    $report += '- `executables-and-dlls.csv` - version info, file sizes, SHA256 for files under 512 MB, and small header signatures.'
    $report += '- `ini-summary.csv` - INI file sizes and section names only, not full config contents.'
    $report += '- `largest-files.csv` - top 50 files by size.'
    $report += '- `layout.csv` - common UE folder checks.'
    $report += '- `steam-manifests.csv` - matching Steam app manifest clues if found.'
    $report += ''
    $report += '## File Groups'
    $report += ''
    if ($fileGroups.Count -eq 0) {
        $report += '- No interesting files found.'
    }
    else {
        foreach ($group in $fileGroups) {
            $report += ('- `{0}`: {1} files, {2} MB' -f $group.Kind, $group.Count, $group.TotalSizeMB)
        }
    }
    $report += ''
    $report += '## Likely UE Layout'
    $report += ''
    foreach ($entry in $layout) {
        $mark = if ($entry.Exists) { 'yes' } else { 'no' }
        $report += ('- `{0}`: {1}' -f $entry.RelativePath, $mark)
    }
    $report += ''
    $report += '## Largest Package Files'
    $report += ''
    $topPackages = @($packageSummaries | Sort-Object SizeBytes -Descending | Select-Object -First 20)
    if ($topPackages.Count -eq 0) {
        $report += '- No `.pak`, `.utoc`, or `.ucas` files found.'
    }
    else {
        foreach ($package in $topPackages) {
            $report += ('- `{0}` - {1} MB' -f $package.RelativePath, $package.SizeMB)
        }
    }
    $report += ''
    $report += '## Legacy Bethesda Data'
    $report += ''
    $topLegacyData = @($legacyDataSummaries | Sort-Object SizeBytes -Descending | Select-Object -First 20)
    if ($topLegacyData.Count -eq 0) {
        $report += '- No `.bsa`, `.esm`, `.esp`, or `.esl` files found.'
    }
    else {
        foreach ($file in $topLegacyData) {
            $report += ('- `{0}` - {1} MB' -f $file.RelativePath, $file.SizeMB)
        }
    }
    $report += ''
    $report += '## Safety'
    $report += ''
    $report += 'This research pass stores metadata only. It does not copy game assets or dump proprietary package contents.'

    $report | Set-Content -LiteralPath $reportPath -Encoding UTF8

    [PSCustomObject]@{
        RunPath = $runPath
        Report = $reportPath
        Summary = $summaryPath
        Packages = $packagesPath
        LegacyData = $legacyDataPath
        Executables = $versionsPath
        IniSummary = $iniPath
        LargestFiles = $largestPath
        Layout = $layoutPath
        SteamManifests = $steamPath
        TotalFiles = $allFiles.Count
        PackageFiles = $packages.Count
        LegacyDataFiles = $legacyData.Count
        ExecutablesAndDlls = $executables.Count
        IniFiles = $iniFiles.Count
    }
}

function Export-CyrodiilMPCsv {
    param(
        [object[]]$Rows,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Columns
    )

    if ($Rows.Count -eq 0) {
        ($Columns -join ',') | Set-Content -LiteralPath $Path -Encoding UTF8
        return
    }

    $Rows | Select-Object $Columns | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

Export-ModuleMember -Function @(
    'Get-CyrodiilMPRoot',
    'Get-CyrodiilMPResearchPath',
    'Get-CyrodiilMPDefaultGameCandidates',
    'Resolve-CyrodiilMPGamePath',
    'Find-CyrodiilMPUnrealFiles',
    'New-CyrodiilMPGameInventory',
    'Open-CyrodiilMPFModel',
    'New-CyrodiilMPResearchRun',
    'New-CyrodiilMPFullResearch'
)
