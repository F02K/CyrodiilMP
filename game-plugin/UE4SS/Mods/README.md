# UE4SS Mods

CyrodiilMP Lua mods live here and are installed into:

```text
OblivionRemastered\Binaries\Win64\Mods
```

Install them with:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

Current mods:

- `CyrodiilMP_MultiplayerPrototype` - first raw UDP multiplayer Lua prototype.
- `CyrodiilMP_RuntimeInspector` - runtime object/menu dump helper.
- `CyrodiilMP_AutoUSMAP` - optional helper that calls `DumpUSMAP()` after launch.

Future gameplay Lua should call C++ helpers registered by the `RE-UE4SS` fork.
