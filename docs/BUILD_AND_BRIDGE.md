# Build And Bridge

The managed `CyrodiilMP.ClientBridge` was an early smoke-test bridge for proving
menu-click-to-server round trips. It is no longer the runtime direction.

## Active Build

Build the .NET utilities:

```powershell
.\scripts\build.cmd -Configuration Debug
```

Build the native launcher/bootstrap/GameClient stack:

```powershell
.\scripts\build-native.cmd -Configuration Release
```

Install the standalone loader path:

```powershell
.\scripts\install-standalone-loader.cmd -Configuration Release
```

## Retired Bridge Flow

The old flow was:

```text
UE4SS menu hook
  -> CyrodiilMP.ClientBridge.exe
  -> LiteNetLib menu-connect request
  -> client-bridge-result.json
```

Keep `client/CyrodiilMP.ClientBridge` only for historical smoke tests unless we
intentionally delete it in a cleanup pass.

UE4SS is no longer used for runtime UI, loading, or multiplayer connection flow.
Use it only for research/dumper helpers documented in `docs/UE4SS_RESEARCH.md`.
