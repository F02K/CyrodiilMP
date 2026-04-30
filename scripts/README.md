# Helper Scripts

Use the `.cmd` wrappers when double-clicking from Explorer. They keep the window
open so success messages and errors do not disappear immediately.

## UE4SS Setup

Initializes or updates the direct `RE-UE4SS` submodule and its dependencies.

```powershell
.\scripts\setup-ue4ss.cmd
```

If UE4SS submodules need HTTPS rewriting:

```powershell
.\scripts\setup-ue4ss.cmd -UseHttpsSubmodules
```

## Dashboard

```powershell
.\scripts\run-dashboard.cmd -Port 5088
.\scripts\start-dashboard-background.cmd -Port 5088
.\scripts\stop-dashboard.cmd
```

Open:

```text
http://127.0.0.1:5088
```

## Build

Builds the shared protocol library, server, and dashboard.

```powershell
.\scripts\build.cmd -Configuration Debug
```

Builds the `F02K/RE-UE4SS` fork and checks that the runtime DLLs were produced.
This currently requires the nested `deps/first/Unreal` pseudo-source checkout to
exist and be accessible.

```powershell
.\scripts\build-ue4ss.cmd -Configuration Release
```

Protocol smoke for the raw UDP v0 sidecar:

```powershell
.\scripts\test-udp-sidecar.cmd -Port 27016
```

## Server

Starts the local dedicated server helper.

```powershell
.\scripts\run-server.cmd -Port 27015
```

The server starts the raw UDP sidecar on port `27016` by default. Override it
when needed:

```powershell
.\scripts\run-server.cmd -Port 27015 -NativePort 27016
```

## Install UE4SS Runtime

Copies the built UE4SS runtime files and base UE4SS Mods folder into Oblivion
Remastered `Binaries\Win64`.

```powershell
.\scripts\install-ue4ss-runtime.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

## Install UE4SS Lua Mods

Copies CyrodiilMP Lua mods into the Oblivion Remastered `Win64\Mods` folder and
enables them when `mods.txt` exists.

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

Optional AutoUSMAP helper:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -IncludeAutoUSMAP
```

## Research Helpers

```powershell
.\scripts\quick-scan.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
.\scripts\full-research.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
.\scripts\new-research-run.cmd -Name "ue-object-notes"
.\scripts\collect-runtime-dumps.cmd -Name main-menu-pass
.\scripts\analyze-runtime-dump.cmd
.\scripts\index-fmodel-export.cmd -ExportPath "D:\FModelExports\OblivionMenu" -Name main-menu-pass
```

UE4SS quality-of-life helpers:

```powershell
.\scripts\fix-ue4ss-gui.cmd
.\scripts\set-usmap-hotkey.cmd -Key F6
.\scripts\install-auto-usmap-dumper.cmd -DelaySeconds 12
```

FModel helper:

```powershell
.\scripts\open-fmodel.cmd
```
