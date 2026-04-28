param(
    [Parameter(Mandatory = $true)]
    [string]$ExportPath,
    [string]$Name = 'fmodel-export'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExportPath -PathType Container)) {
    throw "ExportPath does not exist or is not a directory: $ExportPath"
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedExportPath = (Resolve-Path -LiteralPath $ExportPath).Path
$safeName = $Name -replace '[^a-zA-Z0-9._-]', '-'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputDir = Join-Path $root "research\fmodel-index\$stamp-$safeName"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$textExtensions = @(
    '.json', '.txt', '.csv', '.ini', '.log', '.uexp.txt', '.uasset.txt'
)

$files = @(Get-ChildItem -LiteralPath $resolvedExportPath -Recurse -File -ErrorAction SilentlyContinue)
$textFiles = @($files | Where-Object {
    $extension = $_.Extension.ToLowerInvariant()
    $textExtensions -contains $extension -or $_.Name.ToLowerInvariant().EndsWith('.uasset.json')
})

$assetPathPattern = '(/Game/[A-Za-z0-9_./-]+|/Script/[A-Za-z0-9_./:-]+|/Engine/[A-Za-z0-9_./-]+)'
$classNamePattern = '\b([A-Z][A-Za-z0-9_]*(?:Widget|Button|Menu|Controller|Character|Pawn|GameMode|Subsystem|Component|Actor|Blueprint|AnimInstance|HUD))\b'

$references = New-Object System.Collections.Generic.List[object]
$classes = New-Object System.Collections.Generic.List[object]
$fileSummaries = New-Object System.Collections.Generic.List[object]

foreach ($file in $textFiles) {
    $relativePath = $file.FullName.Substring($resolvedExportPath.Length).TrimStart('\')
    $content = ''
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    }
    catch {
        continue
    }

    $assetMatches = [regex]::Matches($content, $assetPathPattern) |
        ForEach-Object { $_.Value.TrimEnd('.', ',', ';', ')', ']', '"', "'") } |
        Sort-Object -Unique

    $classMatches = [regex]::Matches($content, $classNamePattern) |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique

    $fileSummaries.Add([PSCustomObject]@{
        RelativePath = $relativePath
        SizeBytes = $file.Length
        AssetReferenceCount = @($assetMatches).Count
        ClassCandidateCount = @($classMatches).Count
        LastWriteTime = $file.LastWriteTime.ToString('o')
    })

    foreach ($reference in $assetMatches) {
        $references.Add([PSCustomObject]@{
            SourceFile = $relativePath
            Reference = $reference
            Kind = if ($reference.StartsWith('/Script/')) { 'script' } elseif ($reference.StartsWith('/Engine/')) { 'engine' } else { 'game' }
        })
    }

    foreach ($class in $classMatches) {
        $classes.Add([PSCustomObject]@{
            SourceFile = $relativePath
            ClassCandidate = $class
        })
    }
}

$referenceGroups = @($references | Group-Object Reference | Sort-Object Count -Descending | ForEach-Object {
    [PSCustomObject]@{
        Reference = $_.Name
        Count = $_.Count
        Kind = $_.Group[0].Kind
    }
})

$classGroups = @($classes | Group-Object ClassCandidate | Sort-Object Count -Descending | ForEach-Object {
    [PSCustomObject]@{
        ClassCandidate = $_.Name
        Count = $_.Count
    }
})

$filesCsv = Join-Path $outputDir 'files.csv'
$refsCsv = Join-Path $outputDir 'references.csv'
$refSummaryCsv = Join-Path $outputDir 'reference-summary.csv'
$classesCsv = Join-Path $outputDir 'class-candidates.csv'
$reportPath = Join-Path $outputDir 'report.md'

$fileSummaries | Export-Csv -LiteralPath $filesCsv -NoTypeInformation -Encoding UTF8
$references | Export-Csv -LiteralPath $refsCsv -NoTypeInformation -Encoding UTF8
$referenceGroups | Export-Csv -LiteralPath $refSummaryCsv -NoTypeInformation -Encoding UTF8
$classGroups | Export-Csv -LiteralPath $classesCsv -NoTypeInformation -Encoding UTF8

$uiRefs = @($referenceGroups | Where-Object {
    $_.Reference -match '(?i)(menu|widget|ui|hud|button|title|main)'
} | Select-Object -First 60)

$uiClasses = @($classGroups | Where-Object {
    $_.ClassCandidate -match '(?i)(menu|widget|button|hud|controller)'
} | Select-Object -First 60)

$report = @()
$report += '# FModel Export Index'
$report += ''
$report += "- Created: $((Get-Date).ToString('o'))"
$report += ('- Export path: `{0}`' -f $resolvedExportPath)
$report += "- Files scanned: $($files.Count)"
$report += "- Text-like files scanned: $($textFiles.Count)"
$report += "- Unique references: $($referenceGroups.Count)"
$report += "- Unique class candidates: $($classGroups.Count)"
$report += ''
$report += '## Files Written'
$report += ''
$report += '- `files.csv` - scanned file summary.'
$report += '- `references.csv` - per-file asset/script references.'
$report += '- `reference-summary.csv` - unique references by count.'
$report += '- `class-candidates.csv` - class-like names by count.'
$report += ''
$report += '## UI/Menu Reference Candidates'
$report += ''
if ($uiRefs.Count -eq 0) {
    $report += '- No obvious UI/menu references found.'
}
else {
    foreach ($reference in $uiRefs) {
        $report += ('- `{0}` ({1})' -f $reference.Reference, $reference.Count)
    }
}
$report += ''
$report += '## UI/Menu Class Candidates'
$report += ''
if ($uiClasses.Count -eq 0) {
    $report += '- No obvious UI/menu class candidates found.'
}
else {
    foreach ($class in $uiClasses) {
        $report += ('- `{0}` ({1})' -f $class.ClassCandidate, $class.Count)
    }
}

$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host 'FModel export index complete.'
Write-Host "Output: $outputDir"
Write-Host "Report: $reportPath"
Write-Host "References: $refsCsv"
Write-Host "Class candidates: $classesCsv"
Write-Host ''
Get-Content -LiteralPath $reportPath | Select-Object -First 80 | ForEach-Object { Write-Host $_ }
