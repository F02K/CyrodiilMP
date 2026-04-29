# Helper Scripts

These scripts collect first data for the CyrodiilMP prototype without modifying the game folder.

Use the `.cmd` wrappers when double-clicking from Explorer. They keep the window open so success messages and errors do not disappear immediately.

## Dashboard

Starts a small local web dashboard for inspecting research runs and launching the full research pass.

On the first run, the launcher will restore NuGet packages automatically if the dashboard project has not been restored yet.

```powershell
.\scripts\run-dashboard.cmd -Port 5088
```

To start it in the background:

```powershell
.\scripts\start-dashboard-background.cmd -Port 5088
```

To stop a background dashboard:

```powershell
.\scripts\stop-dashboard.cmd
```

Open:

```text
http://127.0.0.1:5088
```

## Repository Layout Audit

Prints a categorized map of source, generated, local-tool, vendor, and research folders. This is non-destructive.

```powershell
.\scripts\audit-repo-layout.cmd
```

To also write a Markdown report under `research/repo-audits/`:

```powershell
.\scripts\audit-repo-layout.cmd -WriteReport
```

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

Or put the install path in `game-path.txt` at the project root. This repo currently uses:

```text
F:\Steam\steamapps\common\Oblivion Remastered
```

Output goes to `research/game-inventory/` as Markdown and JSON.

## Full Research Pass

Collects a structured metadata bundle from the game install. This is the main first-data helper.

```powershell
.\scripts\full-research.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

It writes a timestamped folder under `research/full-research/` containing:

- `report.md`
- `summary.json`
- `packages.csv`
- `legacy-data.csv`
- `executables-and-dlls.csv`
- `ini-summary.csv`
- `largest-files.csv`
- `layout.csv`
- `steam-manifests.csv`

The script collects metadata only. It does not copy game assets or extract package contents. It also detects classic Bethesda-style data files like `.bsa`, `.esm`, `.esp`, and `.esl` when present.

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

## Fix UE4SS GUI

Makes the UE4SS GUI console visible so you can generate `Mappings.usmap` for FModel.

```powershell
.\scripts\fix-ue4ss-gui.cmd
```

This updates `UE4SS-settings.ini` in the game `Win64` folder and creates a `.bak-CyrodiilMP` backup first.

## Set USMAP Hotkey

Changes the UE4SS `DumpUSMAP` keybind from `Ctrl+Numpad 6` to an easier key such as `Ctrl+F6`.

```powershell
.\scripts\set-usmap-hotkey.cmd -Key F6
```

## Install Auto USMAP Dumper

Installs a tiny UE4SS Lua mod that automatically calls `DumpUSMAP()` after launch, so no keyboard shortcut is needed.

```powershell
.\scripts\install-auto-usmap-dumper.cmd -DelaySeconds 12
```

## Index FModel Export

Indexes text/JSON exports from FModel and extracts likely `/Game`, `/Script`, UI, menu, widget, and class references.

```powershell
.\scripts\index-fmodel-export.cmd -ExportPath "D:\FModelExports\OblivionMenu" -Name main-menu-pass
```

## Install CyrodiilMP UE4SS Mods

Installs the runtime inspector and the GameClient Lua bootstrap into the UE4SS `Mods` folder. It also copies the built standalone native GameClient into the game `Win64\CyrodiilMP\GameClient` folder.

The bootstrap only loads `CyrodiilMP.GameClient.dll`. UI edits are intentionally kept out of Lua; the native UE4SS GameHost owns menu relabeling once RE-UE4SS dependencies are available.

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

After launching the game, runtime dumps should appear in the game `Win64\CyrodiilMP_RuntimeDumps` folder.

The optional UE4SS C++ GameHost is not installed by default. If you build that experimental path later, install it explicitly:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -IncludeUe4ssGameHost
```

## Collect Runtime Dumps

Copies UE4SS runtime inspector CSV/Markdown files back into the repo for analysis.

```powershell
.\scripts\collect-runtime-dumps.cmd -Name main-menu-pass
```

## Analyze Runtime Dump

Builds a focused menu/button target report from a collected UE4SS runtime dump.

```powershell
.\scripts\analyze-runtime-dump.cmd -DumpPath ".\research\runtime-dumps\20260428-143538-runtime"
```

If no path is passed, it analyzes the latest folder under `research\runtime-dumps`.

The analyzer writes these files into the dump folder:

- `menu-analysis.md`
- `menu-candidates.csv`
- `main-menu-wrappers.csv`
- `menu-analysis.json`
- `generated-main-menu-targets.lua`

The current menu probe shows six main-menu wrappers: `main_continue_wrapper`, `main_new_wrapper`, `main_load_wrapper`, `main_options_wrapper`, `main_credits_wrapper`, and `main_exit_wrapper`.

## New Research Run

Creates a timestamped folder for notes, screenshots, logs, and dumps.

```powershell
.\scripts\new-research-run.ps1 -Name "first-fmodel-pass"
```

If PowerShell script execution is blocked:

```powershell
.\scripts\new-research-run.cmd -Name "first-fmodel-pass"
```

Output goes to `research/runs/`. The helper creates `README.md`, `notes.md`, and `status.txt`; the `logs`, `dumps`, and `screenshots` folders are intentionally empty until you add data to them.

## Run The Data-Capture Server

Starts the first dedicated server listener. It accepts LiteNetLib clients with the connection key `CyrodiilMP` and logs connects, disconnects, and raw packet previews.

Like the dashboard launcher, this script now restores NuGet packages automatically on the first run if needed.

```powershell
.\scripts\run-server.cmd -Port 27015
```

This is intentionally just a listener for early client experiments. It does not perform transform replication yet.
It now replies to the bridge `hello` with a simple `server-welcome` packet and replies to `menu-connect` with `menu-connect-ack`, so the first smoke test is a real round-trip handshake.

## Build Everything

Builds the shared protocol library, server, client bridge, probe, and dashboard.

```powershell
.\scripts\build.cmd -Configuration Debug
```

## Build Native GameClient

Builds the standalone native GameClient DLL, test host, and the new standalone loader/bootstrap. This does not require RE-UE4SS.

```powershell
.\scripts\build-native.cmd -Configuration Release
```

## Install Standalone Loader

Installs the native GameClient plus `CyrodiilMP.Bootstrap.dll` and `CyrodiilMP.Launcher.exe` into the game `Win64\CyrodiilMP` folder.

```powershell
.\scripts\install-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered"
```

## Run Standalone Loader

Launches Oblivion Remastered through our own injector instead of relying on UE4SS to load the client.

```powershell
.\scripts\run-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered"
```

To inject into an already running game process:

```powershell
.\scripts\run-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered" -Existing
```

See `docs\STANDALONE_LOADER.md` for the current architecture and next UE bridge steps.

The UE5.3 startup scan can be toggled in the installed bootstrap settings:

```text
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\Bootstrap\settings.ini
```

```ini
[UEBridge]
EnableUEPatternScan=true
```

To also build the C++ UE4SS GameHost mod, first install the RE-UE4SS dependency:

```powershell
.\scripts\setup-native-deps.cmd
```

To track it as a git submodule instead of a plain local vendor checkout:

```powershell
.\scripts\setup-native-deps.cmd -AsSubmodule
```

```powershell
.\scripts\build-native.cmd -Configuration Release -BuildUe4ssGameHost
```

If RE-UE4SS is not under `vendor\RE-UE4SS`, pass it explicitly:

```powershell
.\scripts\build-native.cmd -Configuration Release -Ue4ssRoot "D:\src\RE-UE4SS"
```

## Check UE4SS C++ Template

Clones/checks the official UE4SS C++ template and verifies whether its `UEPseudo` dependency is reachable.

```powershell
.\scripts\check-ue4ss-cpp-template.cmd
```

At the moment this still hits the same upstream blocker as full RE-UE4SS: `git@github.com:Re-UE4SS/UEPseudo.git` is not reachable from this machine.

## Run Native GameClient Manually

Tests the standalone native DLL against the server raw UDP sidecar.

```powershell
.\scripts\run-server.cmd -Port 27015
.\scripts\run-native-gameclient.cmd -Port 27016
```

## Publish Client Bridge

Publishes the short-lived client executable used by the UE4SS main-menu click hook.

```powershell
.\scripts\publish-client-bridge.cmd
```

`install-cyrodiilmp-ue4ss-mods.cmd` also publishes and installs this bridge into the game `Win64\CyrodiilMP\ClientBridge` folder by default.

## Run Client Bridge Manually

Tests the same bridge behavior without launching the game.

```powershell
.\scripts\run-client-bridge.cmd -HostName 127.0.0.1 -Port 27015 -Name ManualBridge
```

Like the other .NET helper launchers, this script restores NuGet packages automatically on the first run if needed.

## Run The Probe Client

Sends fake transform packets to the data-capture server so we can verify connection and packet logging before the Oblivion Remastered client integration exists.

This launcher also restores NuGet packages automatically on the first run if needed.

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
New-CyrodiilMPFullResearch -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
Open-CyrodiilMPFModel
New-CyrodiilMPResearchRun -Name "ue-object-notes"
```
