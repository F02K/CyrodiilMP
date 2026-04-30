# CyrodiilMP

CyrodiilMP is an experimental multiplayer mod project for The Elder Scrolls IV:
Oblivion Remastered.

## Runtime Direction

CyrodiilMP is based on a direct `F02K/RE-UE4SS` submodule. The game-facing client
runtime should be implemented by extending that UE4SS fork with C++ functions
exposed to Lua.

Lua mods under `game-plugin/UE4SS/Mods` orchestrate the game-side behavior. The
dedicated server and shared protocol code stay outside the game process.

## MVP Goal

Run a dedicated CyrodiilMP server that multiple clients can connect to, then show
another connected player in-game with their position synced.

The first playable milestone is intentionally small:

- Start a dedicated server outside the game.
- Connect two Oblivion Remastered clients through the UE4SS-based runtime.
- Spawn a remote player representation in the same area.
- Sync position, rotation, movement state, display name, and basic spawn/despawn.
- Keep combat, quests, inventory, NPCs, world changes, and persistence out of scope until movement is reliable.

## Layout

- `RE-UE4SS/` - direct submodule for the Oblivion Remastered UE4SS runtime fork.
- `game-plugin/UE4SS/Mods/` - CyrodiilMP Lua mods installed into the game `Mods` folder.
- `server/` - authoritative multiplayer server prototype.
- `shared/` - protocol schemas, constants, and shared serialization code.
- `dashboard/` - local browser dashboard for research/install/server helpers.
- `scripts/` - build, setup, research, dashboard, server, and UE4SS Lua install helpers.
- `docs/` - current architecture and workflow notes.
- `research/` - local investigation notes and generated research outputs.

## Common Commands

```powershell
.\scripts\setup-ue4ss.cmd
.\scripts\build.cmd -Configuration Debug
.\scripts\run-dashboard.cmd -Port 5088
.\scripts\run-server.cmd -Port 27015
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -GamePath "D:\SteamLibrary\steamapps\common\Oblivion Remastered"
```

The helper scripts accept `-GamePath`, `CYRODIILMP_GAME_DIR`, or the local
`game-path.txt` file.

## License And Rights

CyrodiilMP's original code and documentation are released under the MIT License.
See `LICENSE`.

This does not grant rights to Oblivion Remastered, Bethesda/Microsoft/ZeniMax
materials, Unreal Engine/Epic materials, game assets, trademarks, third-party
tools, or extracted proprietary content. See `NOTICE.md`.
