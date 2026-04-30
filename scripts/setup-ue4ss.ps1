param(
    [switch]$AsSubmodule,
    [switch]$UseHttpsSubmodules,
    [string]$Ref = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ue4ssRoot = Join-Path $projectRoot 'RE-UE4SS'
$repoUrl = 'https://github.com/F02K/RE-UE4SS.git'

function Invoke-CheckedGit {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$FailureMessage = 'git command failed'
    )

    git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (exit $LASTEXITCODE)"
    }
}

function Update-Ue4ssSubmodules {
    param([string]$Path)

    if ($UseHttpsSubmodules) {
        Invoke-CheckedGit -Arguments @('-C', $Path, 'config', 'url.https://github.com/.insteadOf', 'git@github.com:') `
            -FailureMessage 'Could not configure HTTPS rewrite for RE-UE4SS submodules'
    }

    Invoke-CheckedGit -Arguments @('-C', $Path, 'submodule', 'sync', '--recursive') `
        -FailureMessage 'Could not sync RE-UE4SS submodules'

    Invoke-CheckedGit -Arguments @('-C', $Path, 'submodule', 'update', '--init', '--recursive') `
        -FailureMessage @'
Could not initialize RE-UE4SS submodules.

RE-UE4SS depends on Unreal pseudo-source access. Link your GitHub account to your Epic Games account, make sure the same GitHub credentials are available to git, then rerun this script.

If you do not use GitHub SSH keys, rerun with:
  .\scripts\setup-ue4ss.cmd -UseHttpsSubmodules

RE-UE4SS is the CyrodiilMP runtime base now. Fix this dependency inside the F02K fork before adding another runtime path.
'@
}

if (Test-Path -LiteralPath (Join-Path $ue4ssRoot 'CMakeLists.txt') -PathType Leaf) {
    Write-Host "RE-UE4SS already exists: $ue4ssRoot"
    Write-Host 'Updating submodules...'
    Update-Ue4ssSubmodules -Path $ue4ssRoot
}
elseif ($AsSubmodule) {
    Write-Host "Adding RE-UE4SS as a git submodule..."
    Invoke-CheckedGit -Arguments @('-C', $projectRoot, 'submodule', 'add', $repoUrl, 'RE-UE4SS') `
        -FailureMessage 'Could not add RE-UE4SS submodule'
    Update-Ue4ssSubmodules -Path $ue4ssRoot
}
else {
    Write-Host "Cloning RE-UE4SS into the repository root..."
    Invoke-CheckedGit -Arguments @('clone', $repoUrl, $ue4ssRoot) `
        -FailureMessage 'Could not clone RE-UE4SS'
    Update-Ue4ssSubmodules -Path $ue4ssRoot
}

if (-not [string]::IsNullOrWhiteSpace($Ref)) {
    Write-Host "Checking out RE-UE4SS ref: $Ref"
    Invoke-CheckedGit -Arguments @('-C', $ue4ssRoot, 'fetch', '--all', '--tags') `
        -FailureMessage "Could not fetch RE-UE4SS refs"
    Invoke-CheckedGit -Arguments @('-C', $ue4ssRoot, 'checkout', $Ref) `
        -FailureMessage "Could not checkout RE-UE4SS ref $Ref"
    Update-Ue4ssSubmodules -Path $ue4ssRoot
}

if (-not (Test-Path -LiteralPath (Join-Path $ue4ssRoot 'CMakeLists.txt') -PathType Leaf)) {
    throw "RE-UE4SS setup did not produce CMakeLists.txt at $ue4ssRoot"
}

Write-Host ''
Write-Host 'RE-UE4SS runtime checkout setup complete.'
Write-Host "UE4SS_ROOT: $ue4ssRoot"
Write-Host ''
Write-Host 'Note: CyrodiilMP should extend this fork with C++ functions exposed to Lua.'
