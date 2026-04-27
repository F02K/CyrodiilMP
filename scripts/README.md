# Helper Scripts

These scripts collect first data for the CyrodiilMP prototype without modifying the game folder.

## Quick Scan

Creates a timestamped inventory of Oblivion Remastered files, focused on UE package files and executables.

```powershell
.\scripts\quick-scan.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

If PowerShell script execution is blocked, use the wrapper:

```powershell
.\scripts\quick-scan.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

You can also set the game path once:

```powershell
$env:CYRODIILMP_GAME_DIR = "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
.\scripts\quick-scan.ps1
```

Output goes to `research/game-inventory/` as Markdown and JSON.

## Open FModel

Launches the project-local FModel install.

```powershell
.\scripts\open-fmodel.ps1
```

If PowerShell script execution is blocked:

```powershell
.\scripts\open-fmodel.cmd
```

Use the quick-scan output to pick the correct game/content folder in FModel.

## New Research Run

Creates a timestamped folder for notes, screenshots, logs, and dumps.

```powershell
.\scripts\new-research-run.ps1 -Name "first-fmodel-pass"
```

If PowerShell script execution is blocked:

```powershell
.\scripts\new-research-run.cmd -Name "first-fmodel-pass"
```

Output goes to `research/runs/`.

## Run The Data-Capture Server

Starts the first dedicated server listener. It accepts LiteNetLib clients with the connection key `CyrodiilMP` and logs connects, disconnects, and raw packet previews.

```powershell
.\scripts\run-server.cmd -Port 27015
```

This is intentionally just a listener for early client experiments. It does not perform transform replication yet.

## Run The Probe Client

Sends fake transform packets to the data-capture server so we can verify connection and packet logging before the Oblivion Remastered client integration exists.

In one terminal:

```powershell
.\scripts\run-server.cmd -Port 27015
```

In another terminal:

```powershell
.\scripts\run-net-probe.cmd -HostName 127.0.0.1 -Port 27015 -Name ProbePlayer
```

## PowerShell Module

For interactive work:

```powershell
Import-Module .\scripts\CyrodiilMP.Helpers.psm1 -Force
Resolve-CyrodiilMPGamePath
New-CyrodiilMPGameInventory -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
Open-CyrodiilMPFModel
New-CyrodiilMPResearchRun -Name "ue-object-notes"
```
