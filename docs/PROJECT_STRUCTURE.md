# Project Structure

CyrodiilMP has one game-runtime path now: extend the `F02K/RE-UE4SS` fork and
drive game behavior from Lua.

## Active Runtime Pieces

- `RE-UE4SS/` - direct submodule and primary C++ runtime base.
- `game-plugin/UE4SS/Mods/` - Lua mods copied into the game `Mods` folder.
- `server/` - authoritative dedicated server prototype.
- `shared/` - protocol contracts shared by server and tools.
- `dashboard/` - local web dashboard for setup, research, install, and server helpers.

## UE4SS Boundary

- UE4SS C++ owns low-level UE access, function registration, native networking glue, and unsafe engine calls.
- Lua owns orchestration: connect/disconnect, tick/update scheduling, debug commands, and calls to safe C++ helpers.
- The server remains outside the game process and owns session state.

## First Lua API Targets

- `CyrodiilMP.Connect(host, port, displayName)`
- `CyrodiilMP.Disconnect()`
- `CyrodiilMP.IsConnected()`
- `CyrodiilMP.GetLocalPlayerTransform()`
- `CyrodiilMP.SendLocalPlayerTransform(transform)`
- `CyrodiilMP.PollRemotePlayerUpdates()`
- `CyrodiilMP.SpawnRemotePlayerProxy(playerId, transform)`
- `CyrodiilMP.UpdateRemotePlayerProxy(playerId, transform)`
- `CyrodiilMP.DespawnRemotePlayerProxy(playerId)`

## MVP Flow

```text
Oblivion Remastered
  -> loads RE-UE4SS
      -> registers CyrodiilMP C++ helpers into Lua
          -> CyrodiilMP Lua mod connects to the dedicated server
          -> Lua calls C++ helpers for local/remote player state
```
