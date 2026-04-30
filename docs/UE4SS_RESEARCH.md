# UE4SS Runtime Role

UE4SS is now the primary CyrodiilMP runtime base for Oblivion Remastered. The
project should use and extend the `F02K/RE-UE4SS` fork instead of growing a
separate launcher/bootstrap/runtime hook stack.

The runtime split should be:

- C++ inside the UE4SS fork owns low-level UE access, native networking glue, safe wrappers, and Lua function registration.
- Lua mods under `game-plugin/UE4SS/Mods` own orchestration and call the registered C++ helpers.
- `server/` stays the external authoritative multiplayer server.
- `shared/` stays the protocol/schema home.

Allowed UE4SS uses:

- dump reflected objects, properties, names, and offsets
- generate or collect `.usmap` data
- inspect menus/widgets while the game is running
- cross-check provisional UE pattern scanner results
- load the real CyrodiilMP client runtime
- expose CyrodiilMP C++ functions to Lua
- run the first transform-sync gameplay prototype

Use `scripts/install-cyrodiilmp-ue4ss-mods.ps1` to install the Lua-side helpers
while the UE4SS fork grows the required C++ API.

## First Lua API Targets

The first C++ functions exposed to Lua should stay intentionally small:

- `CyrodiilMP.Connect(host, port, displayName)`
- `CyrodiilMP.Disconnect()`
- `CyrodiilMP.IsConnected()`
- `CyrodiilMP.GetLocalPlayerTransform()`
- `CyrodiilMP.SendLocalPlayerTransform(transform)`
- `CyrodiilMP.PollRemotePlayerUpdates()`
- `CyrodiilMP.SpawnRemotePlayerProxy(playerId, transform)`
- `CyrodiilMP.UpdateRemotePlayerProxy(playerId, transform)`
- `CyrodiilMP.DespawnRemotePlayerProxy(playerId)`

The exact names can change to match UE4SS conventions, but this boundary keeps
unsafe engine interaction in C++ and leaves gameplay flow readable in Lua.
