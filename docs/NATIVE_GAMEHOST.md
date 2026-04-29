# Native GameHost

`CyrodiilMP.GameHost` is the UE4SS C++ mod path for game/UI integration.

The Lua helpers remain useful for research. `CyrodiilMP.GameClient` owns networking. `CyrodiilMP.GameHost` owns UE4SS-specific hooks and UI edits such as relabeling the Credits button to Multiplayer.

## Layout

```text
native/
  CMakeLists.txt
  CMakePresets.json
  CyrodiilMP.GameHost/
    CMakeLists.txt
    dllmain.cpp
    include/
    src/

game-plugin/UE4SS/Mods/CyrodiilMP.GameHost/
  dlls/main.dll
```

## Dependency

The native build needs RE-UE4SS source, not only the packaged UE4SS runtime.
RE-UE4SS submodules may require a GitHub account linked to an Epic Games account because one dependency references Unreal pseudo-source.

Install it locally:

```powershell
.\scripts\setup-native-deps.cmd
```

If you use GitHub HTTPS auth instead of SSH keys:

```powershell
.\scripts\setup-native-deps.cmd -UseHttpsSubmodules
```

Or track it as a git submodule:

```powershell
.\scripts\setup-native-deps.cmd -AsSubmodule
```

Default expected path:

```text
vendor/RE-UE4SS
```

Alternative:

```powershell
.\scripts\build-native.cmd -Configuration Release -Ue4ssRoot "D:\src\RE-UE4SS"
```

## UE4SSCPPTemplate Attempt

We also tested the official `UE4SSCPPTemplate` path:

```powershell
git clone https://github.com/UE4SS-RE/UE4SSCPPTemplate.git vendor\UE4SSCPPTemplate
git -C vendor\UE4SSCPPTemplate submodule update --init --recursive
```

The template still pulls `RE-UE4SS` and its `deps/first/Unreal` submodule. On this machine that submodule resolves to:

```text
git@github.com:Re-UE4SS/UEPseudo.git
```

and fails with `Repository not found`. So the template does not currently bypass the `UEPseudo` blocker.

You can rerun the check with:

```powershell
.\scripts\check-ue4ss-cpp-template.cmd
```

## Build

```powershell
.\scripts\build-native.cmd -Configuration Release
```

The command above builds only the standalone native GameClient by default. To build this UE4SS GameHost too, use:

```powershell
.\scripts\build-native.cmd -Configuration Release -BuildUe4ssGameHost
```

Expected output:

```text
game-plugin\UE4SS\Mods\CyrodiilMP.GameHost\dlls\main.dll
```

## Install

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

The installer does not install `CyrodiilMP.GameHost` by default. Install it explicitly after building it:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -IncludeUe4ssGameHost
```

## Current Native Responsibilities

- Relabel the existing Credits button to `MULTIPLAYER`.
- Register a filtered CommonUI click hook for the repurposed Credits/Multiplayer entry.
- Launch `CyrodiilMP.ClientBridge.exe` on a background thread.
- Drain bridge results on the game thread.
- Export a small C ABI for future DLL/Lua/C#/tool integrations.

## Current Caveat

The C++ GameHost is the correct place for UI edits, but it cannot be built until the UE4SS pseudo-source dependency is available. The old new-button injection path was removed from native code; `ButtonInjector::TryInject()` now only relabels the existing Credits slot.
