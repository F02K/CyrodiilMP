param(
    [string]$TemplateRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
if ([string]::IsNullOrWhiteSpace($TemplateRoot)) {
    $TemplateRoot = Join-Path $projectRoot 'vendor\UE4SSCPPTemplate'
}

$templateRootPath = [System.IO.Path]::GetFullPath($TemplateRoot)
$templateRepoUrl = 'https://github.com/UE4SS-RE/UE4SSCPPTemplate.git'

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    git @Arguments
    return $LASTEXITCODE
}

New-Item -ItemType Directory -Path (Split-Path -Parent $templateRootPath) -Force | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $templateRootPath '.git') -PathType Container)) {
    Write-Host "Cloning UE4SSCPPTemplate -> $templateRootPath"
    $cloneExit = Invoke-Git -Arguments @('clone', $templateRepoUrl, $templateRootPath)
    if ($cloneExit -ne 0) {
        throw "Could not clone UE4SSCPPTemplate (exit $cloneExit)"
    }
}
else {
    Write-Host "UE4SSCPPTemplate already exists: $templateRootPath"
}

Write-Host ''
Write-Host 'Template submodule metadata:'
$gitmodulesPath = Join-Path $templateRootPath '.gitmodules'
if (Test-Path -LiteralPath $gitmodulesPath -PathType Leaf) {
    Get-Content -LiteralPath $gitmodulesPath
}
else {
    Write-Warning "No .gitmodules found at $gitmodulesPath"
}

Write-Host ''
Write-Host 'Checking UEPseudo remotes...'
$remotes = @(
    'https://github.com/UE4SS-RE/UEPseudo.git',
    'https://github.com/RE-UE4SS/UEPseudo.git',
    'git@github.com:Re-UE4SS/UEPseudo.git'
)

$reachable = $false
foreach ($remote in $remotes) {
    Write-Host "git ls-remote $remote"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    git ls-remote $remote *> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -eq 0) {
        Write-Host "Reachable: $remote"
        $reachable = $true
    }
    else {
        Write-Host "Not reachable: $remote"
    }
}

Write-Host ''
if ($reachable) {
    Write-Host 'At least one UEPseudo remote is reachable. Try:'
    Write-Host '  git submodule update --init --recursive'
    Write-Host 'from the template root, then build the C++ mod.'
}
else {
    Write-Warning 'UEPseudo is not reachable. UE4SSCPPTemplate cannot currently build C++ mods that link UE4SS on this machine.'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  1. Ask UE4SS maintainers for the current UEPseudo replacement/access.'
    Write-Host '  2. Provide a complete RE-UE4SS checkout with deps\first\Unreal populated.'
    Write-Host '  3. Keep using Lua for UI edits temporarily, while GameClient owns networking.'
}
