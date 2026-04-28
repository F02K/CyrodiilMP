# CyrodiilMP

CyrodiilMP is an experimental multiplayer mod project for The Elder Scrolls IV: Oblivion Remastered, targeting its Unreal Engine 5 runtime.

## MVP Goal

Run a dedicated CyrodiilMP server that multiple clients can connect to, then show another connected player in-game with their position synced.

The first playable milestone is intentionally small:

- Start a dedicated server outside the game.
- Connect two Oblivion Remastered clients to that server.
- Spawn a remote player representation in the same area.
- Sync position, rotation, movement state, display name, and basic spawn/despawn.
- Keep combat, quests, inventory, NPCs, world changes, and persistence out of scope until the movement prototype is reliable.

## Initial Layout

- `docs/` - design notes, tool choices, architecture decisions.
- `research/` - reverse engineering notes, UE5 runtime notes, packet/state sync experiments.
- `client/` - short-lived client bridge launched from UE4SS for the first connect MVP.
- `game-plugin/` - Remastered-side mod/plugin assets, UE project notes, pak/mod packaging experiments.
- `native/` - native C/C++ code for hooks, UE5 SDK integration, memory integration, or launcher helpers.
- `server/` - authoritative multiplayer server prototype.
- `shared/` - protocol schemas, shared constants, serialization formats.
- `scripts/` - build, packaging, and developer utility scripts.
- `tests/` - automated tests and simulation harnesses.

## First Data Helpers

Use the helper scripts to collect initial UE5/game-folder data without modifying the game install:

```powershell
.\scripts\run-dashboard.cmd -Port 5088
.\scripts\quick-scan.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
.\scripts\full-research.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
.\scripts\open-fmodel.cmd
.\scripts\new-research-run.cmd -Name "first-fmodel-pass"
.\scripts\index-fmodel-export.cmd -ExportPath "D:\FModelExports\OblivionMenu" -Name main-menu-pass
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

See `scripts/README.md` for the full helper list and `docs/BUILD_AND_BRIDGE.md` for the organized build/client-bridge flow.

## License And Rights

CyrodiilMP's original code and documentation are released under the MIT License. See `LICENSE`.

This does not grant rights to Oblivion Remastered, Bethesda/Microsoft/ZeniMax materials, Unreal Engine/Epic materials, game assets, trademarks, third-party tools, or extracted proprietary content. See `NOTICE.md`.

## Early Technical Questions

- What state should be authoritative on the server?
- Which player state should sync first: transform, animation, health, inventory, world cells, quests?
- Will the client integration be a UE5 plugin/mod, a native runtime hook, a launcher-assisted injector, or a mix?
- How should UE5 pak/mod loading, asset conflicts, and any retained Bethesda data formats be handled?
- What is the minimum playable prototype: seeing another player move in the same exterior cell through the dedicated server is the first milestone.
- Which systems still live in legacy Oblivion-style data, and which systems are exposed through UE5 objects, Blueprints, components, or subsystems?
