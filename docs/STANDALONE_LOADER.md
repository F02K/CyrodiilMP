# Standalone Loader

CyrodiilMP is moving toward a standalone native path so the multiplayer client is not blocked by UE4SS C++ template dependencies or Lua-driven UI edits.

The first standalone milestone is intentionally small:

- launch or attach to `OblivionRemastered-Win64-Shipping.exe`
- inject `CyrodiilMP.Bootstrap.dll`
- load `CyrodiilMP.GameClient.dll`
- start the native command watcher and UDP sidecar handshake
- capture a tiny UE startup snapshot for later UE5.3 address discovery

This does not replace the runtime research tools yet. UE4SS can still be useful for dumps, names, widgets, and early object discovery. The standalone loader is the path we can own for the real client.

## Build

```powershell
.\scripts\build-native.cmd -Configuration Release
```

Build the optional NirnLabUIPlatformOR Chromium runtime for the main-menu UI:

```powershell
.\scripts\build-native.cmd -Configuration Release -BuildNirnLabUIPlatformOR
```

This uses the vendored `vendor/vcpkg` submodule by default. Run submodule
initialization first on a fresh checkout:

```powershell
git submodule update --init --recursive
```

This builds:

- `artifacts\native\Release\GameClient\CyrodiilMP.GameClient.dll`
- `artifacts\native\Release\Standalone\CyrodiilMP.Bootstrap.dll`
- `artifacts\native\Release\Standalone\CyrodiilMP.Launcher.exe`
- `artifacts\native\Release\NirnLabUIPlatformOR\NirnLabUIPlatform.dll` when `-BuildNirnLabUIPlatformOR` is used

## Install

```powershell
.\scripts\install-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered"
```

Installed layout:

```text
OblivionRemastered\Binaries\Win64\CyrodiilMP\
  Bootstrap\
    Bootstrap.log
  GameClient\
    CyrodiilMP.GameClient.dll
    GameClient.log
  Standalone\
    CyrodiilMP.Bootstrap.dll
    CyrodiilMP.Launcher.exe
  NirnLabUIPlatformOR\
    NirnLabUIPlatform.dll
  UI\
    cyrodiilmp\
      main-menu-button.html
  Launch-CyrodiilMP.cmd
```

## Run

Launch the game through the standalone launcher:

```powershell
.\scripts\run-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered"
```

Or use the installed game-local launcher command:

```text
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\Launch-CyrodiilMP.cmd
```

Both paths launch/inject `CyrodiilMP.Bootstrap.dll`. Bootstrap then loads
`CyrodiilMP.GameClient.dll`, starts the GameClient command watcher, and starts
the NirnLabUIPlatformOR UI runtime automatically when its DLL is installed.

Or inject into an already running game process:

```powershell
.\scripts\run-standalone-loader.cmd -GamePath "F:\Steam\steamapps\common\Oblivion Remastered" -Existing
```

## Logs

Check these first:

```text
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\Bootstrap\Bootstrap.log
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\Bootstrap\ue-pattern-scan.json
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\GameClient\GameClient.log
```

The current `UEBridge` records the main module base and runs a conservative UE5.3 pattern scan for early runtime anchors such as `GUObjectArray`, `FName::ToString`, `FName::FName(wchar_t*)`, `StaticConstructObject_Internal`, `ProcessEvent`, and `ProcessLocalScriptFunction`.

## Pattern Scan Setting

The scan can be toggled without rebuilding:

```text
F:\Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\CyrodiilMP\Bootstrap\settings.ini
```

```ini
[UEBridge]
EnableUEPatternScan=true
```

Set `EnableUEPatternScan=false` if a game update makes startup scanning unstable. The scanner only reports addresses; it does not call functions or walk UE objects yet.

The bootstrap source layout is documented in `docs\PROJECT_STRUCTURE.md`.

## Multiplayer MVP Direction

The clean standalone MVP path is:

1. Resolve UE runtime addresses from the game process.
2. Read local player pawn location and rotation every tick or timer interval.
3. Send transform snapshots to the dedicated server sidecar.
4. Receive remote player snapshots.
5. Spawn or update a harmless visual proxy for the remote player.
6. Move main-menu UI work into a native overlay or a native UE bridge after transform sync is proven.

That order keeps the first multiplayer proof focused on the thing we actually need most: seeing another player position synced in-game.
