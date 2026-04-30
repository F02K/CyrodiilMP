# Asset And Runtime Inspection

CyrodiilMP needs two kinds of references before we can safely add game-facing
multiplayer behavior through UE4SS and Lua:

- Offline asset references from FModel exports.
- Runtime object/widget references from UE4SS while the game is running.

## FModel Export Index

Export or save relevant FModel inspection output into a folder, then run:

```powershell
.\scripts\index-fmodel-export.cmd -ExportPath "D:\Some\FModel\Export" -Name main-menu-pass
```

The indexer writes:

- `files.csv`
- `references.csv`
- `reference-summary.csv`
- `class-candidates.csv`
- `report.md`

Output goes to `research/fmodel-index/`.

## Runtime Inspector

Install the UE4SS Lua helpers:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

Start Oblivion Remastered and wait at the main menu. The runtime inspector will create:

```text
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP_RuntimeDumps
```

Important files:

- `UserWidget.csv`
- `Widget.csv`
- `Button.csv`
- `WidgetBlueprintGeneratedClass.csv`
- `PlayerController.csv`
- `summary.md`

You can also trigger a fresh dump through the UE console:

```text
cyro_dump_runtime
cyro_dump_ui
```

Then copy the generated metadata back into the repo:

```powershell
.\scripts\collect-runtime-dumps.cmd -Name main-menu-pass
```

Output goes to `research/runtime-dumps/`.

## Connect Button Path

The old UE4SS connect prototype registered:

```text
cyro_connect
```

That prototype was removed with the legacy client path. Use runtime dumps to
identify the main-menu widget/class/function names, then route the real visible
button through the UE4SS C++ API exposed to Lua.
