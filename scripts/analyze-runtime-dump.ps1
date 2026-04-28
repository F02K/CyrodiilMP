param(
    [string]$DumpPath,
    [switch]$Latest
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtimeRoot = Join-Path $projectRoot 'research\runtime-dumps'

function Resolve-DumpPath {
    param(
        [string]$Path,
        [switch]$UseLatest
    )

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        return $resolved.Path
    }

    if ($UseLatest -or [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $runtimeRoot -PathType Container)) {
            throw "Runtime dump root does not exist: $runtimeRoot"
        }

        $latestDump = Get-ChildItem -LiteralPath $runtimeRoot -Directory |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -eq $latestDump) {
            throw "No runtime dump folders found under $runtimeRoot"
        }

        return $latestDump.FullName
    }
}

function Import-DumpCsv {
    param(
        [string]$Directory,
        [string]$FileName
    )

    $path = Join-Path $Directory $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @()
    }

    return @(Import-Csv -LiteralPath $path)
}

function Test-MatchAny {
    param(
        [string]$Value,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Value -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-WidgetName {
    param([string]$FullName)

    if ($FullName -match ':WidgetTree\.([^.\s]+)$') {
        return $Matches[1]
    }

    if ($FullName -match '([^.\s]+)$') {
        return $Matches[1]
    }

    return ''
}

function Get-AssetPath {
    param([string]$FullName)

    if ($FullName -match '(/Game/[^.\s]+)') {
        return $Matches[1]
    }

    return ''
}

function New-Candidate {
    param(
        [string]$Source,
        [object]$Row,
        [string]$Reason
    )

    [pscustomobject]@{
        Source = $Source
        Reason = $Reason
        WidgetName = Get-WidgetName -FullName $Row.FullName
        AssetPath = Get-AssetPath -FullName $Row.FullName
        FullName = $Row.FullName
        ClassName = $Row.ClassName
    }
}

function Get-RowCount {
    param([object]$Rows)

    return @($Rows).Count
}

function ConvertTo-LuaString {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

$resolvedDumpPath = Resolve-DumpPath -Path $DumpPath -UseLatest:$Latest

Write-Host 'Analyzing CyrodiilMP runtime dump.'
Write-Host "Dump: $resolvedDumpPath"

$generatedCsvNames = @('menu-candidates.csv', 'main-menu-wrappers.csv')
$csvFiles = Get-ChildItem -LiteralPath $resolvedDumpPath -Filter '*.csv' -File |
    Where-Object { $generatedCsvNames -notcontains $_.Name } |
    Sort-Object Name
if ($csvFiles.Count -eq 0) {
    throw "No CSV files found in runtime dump: $resolvedDumpPath"
}

$userWidgets = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'UserWidget.csv'
$widgets = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'Widget.csv'
$buttons = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'Button.csv'
$textBlocks = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'TextBlock.csv'
$playerControllers = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'PlayerController.csv'
$pawns = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'Pawn.csv'
$characters = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'Character.csv'
$worlds = Import-DumpCsv -Directory $resolvedDumpPath -FileName 'World.csv'

$menuPatterns = @(
    'MainMenu',
    'WBP_LegacyMenu_Main',
    'PrimaryGameLayout',
    'MenuLayer',
    'ButtonLayout',
    'main_[a-z0-9_]+_wrapper'
)

$connectPatterns = @(
    'MainMenu',
    'WBP_MainMenu_Button',
    'main_[a-z0-9_]+_wrapper',
    'InternalRootButtonBase',
    'CommonButton'
)

$candidates = New-Object System.Collections.Generic.List[object]

foreach ($row in $userWidgets) {
    if (Test-MatchAny -Value $row.FullName -Patterns $menuPatterns) {
        $candidates.Add((New-Candidate -Source 'UserWidget.csv' -Row $row -Reason 'menu widget instance'))
    }
}

foreach ($row in $widgets) {
    if (Test-MatchAny -Value $row.FullName -Patterns $connectPatterns) {
        $candidates.Add((New-Candidate -Source 'Widget.csv' -Row $row -Reason 'connect-button widget candidate'))
    }
}

foreach ($row in $buttons) {
    if (Test-MatchAny -Value $row.FullName -Patterns $connectPatterns) {
        $candidates.Add((New-Candidate -Source 'Button.csv' -Row $row -Reason 'clickable button candidate'))
    }
}

foreach ($row in $textBlocks) {
    if (Test-MatchAny -Value $row.FullName -Patterns $connectPatterns) {
        $candidates.Add((New-Candidate -Source 'TextBlock.csv' -Row $row -Reason 'button label/text candidate'))
    }
}

$dedupedCandidates = @(
    $candidates |
        Sort-Object Source, FullName -Unique
)

$wrapperNames = @(
    $dedupedCandidates |
        Where-Object { $_.WidgetName -match '^main_.*_wrapper$' } |
        Select-Object -ExpandProperty WidgetName -Unique |
        Sort-Object
)

$wrapperRows = foreach ($wrapperName in $wrapperNames) {
    $related = @($dedupedCandidates | Where-Object { $_.FullName -match [regex]::Escape($wrapperName) })
    $internalButton = $related | Where-Object { $_.ClassName -match 'CommonButtonInternalBase' -or $_.FullName -match 'InternalRootButtonBase' } | Select-Object -First 1
    $buttonWidget = $related | Where-Object { $_.ClassName -match 'WBP_MainMenu_Button\.WBP_MainMenu_Button_C' } | Select-Object -First 1
    $wrapper = $related | Where-Object { $_.ClassName -match 'WBP_MainMenu_Button_Wrapper\.WBP_MainMenu_Button_Wrapper_C' -or $_.WidgetName -eq $wrapperName } | Select-Object -First 1

    [pscustomobject]@{
        WrapperName = $wrapperName
        WrapperFullName = if ($wrapper) { $wrapper.FullName } else { '' }
        ButtonWidgetFullName = if ($buttonWidget) { $buttonWidget.FullName } else { '' }
        InternalButtonFullName = if ($internalButton) { $internalButton.FullName } else { '' }
    }
}

$classGroups = @(
    $dedupedCandidates |
        Group-Object ClassName |
        Sort-Object Count -Descending |
        Select-Object Count, Name
)

$candidateCsvPath = Join-Path $resolvedDumpPath 'menu-candidates.csv'
$wrapperCsvPath = Join-Path $resolvedDumpPath 'main-menu-wrappers.csv'
$jsonPath = Join-Path $resolvedDumpPath 'menu-analysis.json'
$luaPath = Join-Path $resolvedDumpPath 'generated-main-menu-targets.lua'
$reportPath = Join-Path $resolvedDumpPath 'menu-analysis.md'

$dedupedCandidates | Export-Csv -LiteralPath $candidateCsvPath -NoTypeInformation -Encoding UTF8
$wrapperRows | Export-Csv -LiteralPath $wrapperCsvPath -NoTypeInformation -Encoding UTF8

$analysis = [pscustomobject]@{
    CreatedAt = (Get-Date).ToString('o')
    DumpPath = $resolvedDumpPath
    Counts = [pscustomobject]@{
        CsvFiles = (Get-RowCount $csvFiles)
        UserWidgets = (Get-RowCount $userWidgets)
        Widgets = (Get-RowCount $widgets)
        Buttons = (Get-RowCount $buttons)
        TextBlocks = (Get-RowCount $textBlocks)
        MenuCandidates = (Get-RowCount $dedupedCandidates)
        MainMenuWrappers = (Get-RowCount $wrapperRows)
        PlayerControllers = (Get-RowCount $playerControllers)
        Pawns = (Get-RowCount $pawns)
        Characters = (Get-RowCount $characters)
        Worlds = (Get-RowCount $worlds)
    }
    MainMenuWrappers = $wrapperRows
    CandidateClassGroups = $classGroups
    RecommendedTargets = @(
        '/Game/UI/Modern/MenuLayer/MainMenu/WBP_Modern_MainMenu_ButtonLayout.WBP_Modern_MainMenu_ButtonLayout_C'
        '/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C'
        '/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button.WBP_MainMenu_Button_C'
        '/Script/CommonUI.CommonButtonInternalBase'
    )
}

$analysis | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$luaLines = New-Object System.Collections.Generic.List[string]
$luaLines.Add('-- Generated by scripts/analyze-runtime-dump.ps1')
$luaLines.Add('-- Use as reference data for UE4SS menu/button experiments.')
$luaLines.Add('return {')
$luaLines.Add('  menu_button_layout_class = "/Game/UI/Modern/MenuLayer/MainMenu/WBP_Modern_MainMenu_ButtonLayout.WBP_Modern_MainMenu_ButtonLayout_C",')
$luaLines.Add('  main_menu_button_wrapper_class = "/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C",')
$luaLines.Add('  main_menu_button_class = "/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button.WBP_MainMenu_Button_C",')
$luaLines.Add('  common_button_internal_class = "/Script/CommonUI.CommonButtonInternalBase",')
$luaLines.Add('  wrappers = {')
foreach ($wrapper in $wrapperRows) {
    $luaLines.Add('    {')
    $luaLines.Add('      name = ' + (ConvertTo-LuaString $wrapper.WrapperName) + ',')
    $luaLines.Add('      wrapper = ' + (ConvertTo-LuaString $wrapper.WrapperFullName) + ',')
    $luaLines.Add('      button_widget = ' + (ConvertTo-LuaString $wrapper.ButtonWidgetFullName) + ',')
    $luaLines.Add('      internal_button = ' + (ConvertTo-LuaString $wrapper.InternalButtonFullName))
    $luaLines.Add('    },')
}
$luaLines.Add('  }')
$luaLines.Add('}')
$luaLines | Set-Content -LiteralPath $luaPath -Encoding UTF8

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Runtime Menu Analysis')
$report.Add('')
$report.Add(('- Created: {0}' -f (Get-Date).ToString('o')))
$report.Add(('- Dump: `{0}`' -f $resolvedDumpPath))
$report.Add(('- CSV files: {0}' -f (Get-RowCount $csvFiles)))
$report.Add('')
$report.Add('## Counts')
$report.Add('')
$report.Add(('- User widgets: {0}' -f (Get-RowCount $userWidgets)))
$report.Add(('- Widgets: {0}' -f (Get-RowCount $widgets)))
$report.Add(('- Buttons: {0}' -f (Get-RowCount $buttons)))
$report.Add(('- Text blocks: {0}' -f (Get-RowCount $textBlocks)))
$report.Add(('- Menu candidates: {0}' -f (Get-RowCount $dedupedCandidates)))
$report.Add(('- Main menu wrappers: {0}' -f (Get-RowCount $wrapperRows)))
$report.Add(('- Player controllers: {0}' -f (Get-RowCount $playerControllers)))
$report.Add(('- Pawns: {0}' -f (Get-RowCount $pawns)))
$report.Add(('- Characters: {0}' -f (Get-RowCount $characters)))
$report.Add(('- Worlds: {0}' -f (Get-RowCount $worlds)))
$report.Add('')
$report.Add('## Main Menu Button Wrappers')
$report.Add('')
if ($wrapperRows.Count -eq 0) {
    $report.Add('No `main_*_wrapper` entries were found. Open the main menu in game and run `cyro_dump_runtime`, then collect again.')
} else {
    foreach ($wrapper in $wrapperRows) {
        $report.Add(('- `{0}`' -f $wrapper.WrapperName))
        if (-not [string]::IsNullOrWhiteSpace($wrapper.WrapperFullName)) {
            $report.Add(('  - Wrapper: `{0}`' -f $wrapper.WrapperFullName))
        }
        if (-not [string]::IsNullOrWhiteSpace($wrapper.ButtonWidgetFullName)) {
            $report.Add(('  - Button widget: `{0}`' -f $wrapper.ButtonWidgetFullName))
        }
        if (-not [string]::IsNullOrWhiteSpace($wrapper.InternalButtonFullName)) {
            $report.Add(('  - Internal button: `{0}`' -f $wrapper.InternalButtonFullName))
        }
    }
}
$report.Add('')
$report.Add('## Useful Targets')
$report.Add('')
$report.Add('- Main menu layout: `/Game/UI/Modern/MenuLayer/MainMenu/WBP_Modern_MainMenu_ButtonLayout.WBP_Modern_MainMenu_ButtonLayout_C`')
$report.Add('- Button wrapper class: `/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C`')
$report.Add('- Button widget class: `/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button.WBP_MainMenu_Button_C`')
$report.Add('- Internal clickable class: `/Script/CommonUI.CommonButtonInternalBase`')
$report.Add('')
$report.Add('## MVP Recommendation')
$report.Add('')
$report.Add('For the first connection experiment, hook or repurpose an existing main-menu wrapper instead of creating brand-new UI from scratch. The safest target is `main_credits_wrapper` or another non-critical wrapper, because its internal `CommonButtonInternalBase` is already clickable and visible in the menu. Once that proves `cyro_connect` can be triggered from UI, we can try cloning `WBP_MainMenu_Button_Wrapper_C` or adding a sibling to `WBP_Modern_MainMenu_ButtonLayout_C`.')
$report.Add('')
$report.Add('Generated files:')
$report.Add('')
$report.Add('- `menu-candidates.csv`')
$report.Add('- `main-menu-wrappers.csv`')
$report.Add('- `menu-analysis.json`')
$report.Add('- `generated-main-menu-targets.lua`')

$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host ''
Write-Host 'Runtime dump analysis complete.'
Write-Host "Report: $reportPath"
Write-Host "Candidates: $candidateCsvPath"
Write-Host "Wrappers: $wrapperCsvPath"
Write-Host "JSON: $jsonPath"
Write-Host "Lua targets: $luaPath"
Write-Host ''
Get-Content -LiteralPath $reportPath | ForEach-Object { Write-Host $_ }
