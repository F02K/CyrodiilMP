# Repository Organization

## Active Source

- `RE-UE4SS/` - direct submodule for the F02K UE4SS fork.
- `game-plugin/UE4SS/Mods/` - Lua mods installed into Oblivion Remastered.
- `server/` - dedicated server prototype.
- `shared/` - protocol code and notes.
- `dashboard/` - local web dashboard.
- `scripts/` - reproducible setup/build/install/research helpers.
- `build/` - PowerShell build internals.
- `docs/` - current architecture and workflow notes.

## Local Or Generated

- `artifacts/` - compiled or packaged outputs.
- `bin/`, `obj/` - .NET build outputs.
- `.dotnet-home/` - local .NET/NuGet cache.
- `tools/FModel/current/` and `tools/UE4SS/current/` - local downloaded tools.
- `research/game-inventory/`, `research/full-research/`, `research/runtime-dumps/`, and similar generated research folders.

Do not commit generated game assets, extracted game content, logs, dumps, or local
tool downloads.

## Desired Shape

```text
RE-UE4SS/               Oblivion Remastered UE4SS runtime fork
game-plugin/UE4SS/      Lua orchestration calling CyrodiilMP C++ helpers
server/                 authoritative multiplayer prototype
shared/                 protocol/contracts
dashboard/              local helper UI
scripts/                build/install/research helpers
research/               notes and generated investigation outputs
```
