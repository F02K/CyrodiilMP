# Repository Organization

CyrodiilMP has three different kinds of folders right now: source, local/generated output, and research evidence. Keep those mentally separate.

## Active Source Folders

- `server/` - dedicated server and raw UDP sidecar.
- `shared/` - protocol code and shared notes.
- `native/` - standalone injected runtime, native client DLL, launcher, and future owned UI integration.
- `client/` - retired/experimental managed bridge used by early menu-connect smoke tests.
- `dashboard/` - local web dashboard for research and helper execution.
- `game-plugin/` - UE4SS Lua research/dumper mods and game-side mod packaging experiments.
- `scripts/` - developer entry points. Prefer adding script wrappers here instead of one-off commands in docs.
- `build/` - repo build/publish PowerShell internals, not generated build output.
- `docs/` - architecture and workflow decisions.
- `tests/` - test/probe executables.

## Local Or Generated Folders

These should not be treated as source and are ignored by git.

- `artifacts/` - compiled/published outputs.
- `native/build/` - CMake build tree.
- `bin/`, `obj/` under .NET projects - normal .NET outputs.
- `.dotnet-home/` - local .NET/NuGet cache.
- `tools/FModel/current/` - local downloaded FModel install.
- `tools/UE4SS/current/` - local downloaded UE4SS install.
- `vendor/RE-UE4SS/` - local research dependency checkout, not part of the runtime path.
- `vendor/UE4SSCPPTemplate/` - local historical template experiment.

These can usually be regenerated. Do not commit their contents.

## Research Folders

`research/` is intentionally a workspace, not product source.

- `research/runs/` - human notes and focused investigations.
- `research/runtime-dumps/` - copied UE4SS/runtime dumps.
- `research/full-research/` - generated game install metadata.
- `research/game-inventory/` - generated quick-scan inventories.
- `research/fmodel-index/` - generated FModel export indexes.
- `research/dashboard-runtime/` - dashboard process state.
- `research/net-smoke/` - generated networking smoke logs.
- `research/sample-fmodel-export/` - sample export data.

Keep useful written notes. Generated CSV/JSON/log dumps should stay ignored unless there is a very specific reason to preserve one.

## Experimental Or Legacy Areas

- `native/CyrodiilMP.GameHost/` is a retired UE4SS C++ UI experiment. Do not add new runtime work there.
- `game-plugin/UE4SS/Mods/CyrodiilMP_ConnectButtonPrototype/` and `CyrodiilMP_GameClientBootstrap/` are retired Lua runtime prototypes.
- `client/CyrodiilMP.ClientBridge/` is useful only for historical smoke tests; the runtime path is native `GameClient` plus standalone bootstrap.

## Cleanup Policy

Do not delete folders manually unless they are clearly generated or ignored. Use the audit helper first:

```powershell
.\scripts\audit-repo-layout.cmd
```

If a folder is active source, move/refactor it intentionally with docs and script updates. If a folder is generated output, prefer cleaning it with a script so the action is repeatable.

## Desired Direction

The target shape for the multiplayer MVP is:

```text
server/                 authoritative multiplayer prototype
shared/                 protocol/contracts
native/
  CyrodiilMP.Launcher   process launch/injection only
  CyrodiilMP.Bootstrap  UE runtime discovery and GameClient loading
  CyrodiilMP.GameClient networking/runtime client
research/               evidence and reverse engineering notes
scripts/                reproducible build/install/research helpers
```

Anything that does not fit that shape should either become documented research, be isolated as an experiment, or be removed later in a deliberate cleanup pass.
