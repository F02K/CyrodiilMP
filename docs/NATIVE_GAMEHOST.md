# Native GameHost

`CyrodiilMP.GameHost` was the UE4SS C++ mod experiment for menu/UI integration.
It is retired as a runtime direction.

CyrodiilMP now owns the launcher/bootstrap path directly:

```text
CyrodiilMP.Launcher.exe
  -> injects CyrodiilMP.Bootstrap.dll
      -> scans UE runtime anchors
      -> loads CyrodiilMP.GameClient.dll
      -> later owns native UI/NirnLab integration
```

UE4SS remains useful for research-only workflows:

- object and property dumps
- `.usmap` generation
- widget/menu discovery
- validating names, offsets, and provisional signatures

Do not add new gameplay, UI, networking, or loader responsibilities to
`CyrodiilMP.GameHost`. New runtime work should go into the standalone native
launcher/bootstrap/GameClient stack.
