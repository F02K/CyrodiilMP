# Installed Tools

These tools are kept project-local so CyrodiilMP can be moved or backed up without depending on system-wide installs.

## FModel

- Path: `tools/FModel/current/FModel.exe`
- Installed release: `dec-2025`
- Purpose: inspect Unreal Engine 5 packages, cooked assets, asset paths, dependencies, meshes, textures, animations, and package structure.

## UE4SS / RE-UE4SS

- Path: `tools/UE4SS/current/`
- Installed release: `v3.0.1`
- Purpose: research UE runtime objects, generate SDK/header dumps if compatible, inspect reflected classes/functions/properties, and prototype runtime scripting hooks.

Do not drop UE4SS into the game folder blindly. First confirm the exact Oblivion Remastered executable layout, UE version, anti-tamper behavior, and modding expectations.

## Existing System Tools

- Git is installed.
- .NET SDK is installed and used for `server/CyrodiilMP.Server`.
- CMake is installed for native C/C++ experiments.
- Python is installed for research scripts and small tooling.

## Server Dependency

- `LiteNetLib` `2.1.2` is installed in `server/CyrodiilMP.Server`.
- Purpose: lightweight reliable UDP networking for the dedicated server prototype.
