# Project Structure

CyrodiilMP is still early, so the most important rule is to keep experiments from hardening into one giant file. This is the current ownership map.

## Runtime Pieces

- `server/` - dedicated server prototype and packet capture. This should stay game-agnostic.
- `shared/` - protocol models, serialization, constants, and anything used by both server and clients.
- `native/CyrodiilMP.GameClient/` - native client networking/runtime helper DLL. This owns server connection behavior, command watching, and later transform send/receive calls exposed to the game runtime.
- `native/CyrodiilMP.Bootstrap/` - injected standalone DLL. This owns process startup, settings, UE runtime discovery, and loading `CyrodiilMP.GameClient.dll`.
- `native/CyrodiilMP.Launcher/` - small process launcher/injector. This should stay dumb and not contain game logic.
- `game-plugin/UE4SS/` - research/bootstrap-only UE4SS Lua assets. This should not own final gameplay behavior.

## Bootstrap Source Layout

- `Bootstrap.cpp` - lifecycle orchestration: derive paths, load settings, initialize UEBridge, load GameClient.
- `Settings.*` - bootstrap settings file creation and parsing.
- `Log.*` - file logging.
- `PatternScanner.*` - generic PE section and byte-pattern scanner. It should not know about Unreal names.
- `UEPatterns.*` - Oblivion Remastered UE5.3 pattern definitions.
- `UEBridge.*` - UE-facing coordinator: module snapshot, pattern scan execution, JSON/log reporting, later UWorld/pawn helpers.
- `DllMain.cpp` - minimal DLL attach/detach entry point only.

## Near-Term Refactor Targets

- Move UE address results into a typed `UEAddresses` struct once the scanner reliably completes.
- Keep raw pattern definitions in `UEPatterns.*`; do not scatter signatures through gameplay code.
- Add a separate `UEObjectRuntime.*` when we start reading `GUObjectArray`, names, objects, worlds, or pawns.
- Add a separate `PlayerTransformProbe.*` for local pawn transform reads before connecting that data to networking.
- Keep UI work out of the transform-sync path. Menu or overlay work should live in its own module after the player-position MVP is stable.

## Current MVP Flow

```text
CyrodiilMP.Launcher.exe
  -> injects CyrodiilMP.Bootstrap.dll
      -> reads Bootstrap/settings.ini
      -> scans UE runtime anchors
      -> loads CyrodiilMP.GameClient.dll
          -> connects to dedicated server sidecar
```

The first real gameplay milestone is still: read local player transform, send it to the server, receive another player transform, and render or update a remote representation in-game.
