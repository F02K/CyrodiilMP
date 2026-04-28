param(
    [string]$GamePath,
    [int]$DelaySeconds = 12
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CyrodiilMP.Helpers.psm1'
Import-Module $modulePath -Force

$resolvedGamePath = Resolve-CyrodiilMPGamePath -GamePath $GamePath
$win64Path = Join-Path $resolvedGamePath 'OblivionRemastered\Binaries\Win64'
$modsPath = Join-Path $win64Path 'Mods'
$modPath = Join-Path $modsPath 'CyrodiilMP_AutoUSMAP'
$scriptsPath = Join-Path $modPath 'Scripts'
$mainLua = Join-Path $scriptsPath 'main.lua'
$modEnabledPath = Join-Path $modPath 'enabled.txt'
$modsListPath = Join-Path $modsPath 'mods.txt'

if (-not (Test-Path -LiteralPath (Join-Path $win64Path 'UE4SS.dll') -PathType Leaf)) {
    throw "UE4SS.dll was not found in $win64Path"
}

New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null

@"
local delaySeconds = $DelaySeconds

print("[CyrodiilMP_AutoUSMAP] Loaded. Waiting " .. delaySeconds .. " seconds before DumpUSMAP().")

ExecuteWithDelay(delaySeconds * 1000, function()
    print("[CyrodiilMP_AutoUSMAP] Running DumpUSMAP().")
    local ok, err = pcall(function()
        DumpUSMAP()
    end)

    if ok then
        print("[CyrodiilMP_AutoUSMAP] DumpUSMAP() finished. Check the Win64 folder for Mappings.usmap.")
    else
        print("[CyrodiilMP_AutoUSMAP] DumpUSMAP() failed: " .. tostring(err))
    end
end)
"@ | Set-Content -LiteralPath $mainLua -Encoding UTF8

if (-not (Test-Path -LiteralPath $modEnabledPath -PathType Leaf)) {
    New-Item -ItemType File -Path $modEnabledPath -Force | Out-Null
}

if (Test-Path -LiteralPath $modsListPath -PathType Leaf) {
    $modsList = Get-Content -LiteralPath $modsListPath
    if (-not ($modsList | Where-Object { $_ -match '^\s*CyrodiilMP_AutoUSMAP\s*:' })) {
        Add-Content -LiteralPath $modsListPath -Value 'CyrodiilMP_AutoUSMAP : 1'
    }
}

Write-Host 'Installed CyrodiilMP_AutoUSMAP.'
Write-Host "Mod path: $modPath"
Write-Host "Enabled marker: $modEnabledPath"
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Start Oblivion Remastered.'
Write-Host "  2. Wait at least $DelaySeconds seconds after UE4SS loads."
Write-Host '  3. Check Win64 for Mappings.usmap.'
Write-Host ''
Write-Host "Expected file: $(Join-Path $win64Path 'Mappings.usmap')"
