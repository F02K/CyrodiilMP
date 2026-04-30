# Tooling Options

## Oblivion Remastered / UE5 Modding

- **Unreal Engine 5 editor/toolchain** - reference environment for UE5 asset, Blueprint, packaging, and runtime concepts.
- **UE4SS / UE5SS-style scripting and SDK generation tools** - investigate whether Remastered can be introspected or extended through common Unreal scripting/modding approaches.
- **UnrealPak / IoStore tooling** - inspect, extract, and package `.pak` / `.ucas` / `.utoc` content if the game uses standard UE packaging paths.
- **FModel** - browse Unreal Engine packages, assets, names, paths, and cooked content.
- **UModel / UE Viewer** - inspect compatible meshes, textures, animations, and asset references.
- **Asset Registry tools** - map cooked asset names, dependencies, and package structure.
- **Bethesda data inspection tools** - keep TES4Edit/xEdit-style workflows in research if Remastered retains classic records beneath the UE5 presentation layer.

## UE4SS Runtime Integration

- **Visual Studio 2022** - C++ development and Windows debugging for the `RE-UE4SS` fork.
- **UE4SS Lua** - game-side orchestration and runtime inspection.
- **x64dbg** - runtime debugging and reverse engineering.
- **Ghidra** - static reverse engineering and binary analysis.
- **ReClass.NET** - inspect and document runtime memory structures.
- **Unreal Engine SDK dumps** - document reflected classes, functions, properties, components, and network-relevant runtime objects.

## Networking And Server

- **C#/.NET** - practical server option with good tooling, serialization, diagnostics, and Windows support.
- **Rust** - strong server option for correctness, performance, and safe concurrency.
- **Node.js / TypeScript** - fast prototyping option for protocol and lobby tooling.
- **ENet / LiteNetLib / Steam Networking Sockets** - candidate transport libraries depending on language and latency needs.
- **Protocol Buffers / FlatBuffers / MessagePack** - compact structured serialization options.
- **Wireshark** - packet inspection and protocol debugging.

## Development Workflow

- **Git** - source control.
- **GitHub** - issues, project tracking, CI, releases.
- **GitHub Actions** - build/test automation.
- **PowerShell** - Windows-first automation scripts.
- **Python** - research utilities, binary parsing scripts, quick tooling.

## Testing And Debugging

- **Process Monitor** - file/registry access debugging.
- **RenderDoc** - graphics debugging if visual hooks or overlays become necessary.
- **Windows Performance Recorder / Analyzer** - profiling stalls and CPU issues.
- **OBS** - record multiplayer test sessions for bug review.
- **UE console/logging hooks** - capture runtime object state, asset load behavior, and errors.
- **Dedicated save files and test locations** - repeatable in-game scenarios for sync testing.

## Suggested First Stack

For an early prototype, start with:

- UE5 package inspection with FModel, UnrealPak/IoStore tools, and SDK-dump research.
- C++ inside the `RE-UE4SS` fork for runtime helpers exposed to Lua.
- C#/.NET or Rust for the authoritative server.
- MessagePack or Protocol Buffers for network messages.
- LiteNetLib, ENet, or Steam Networking Sockets for UDP-style transport.
- A tiny sync target first: remote player transform, animation state, display name, and basic spawn/despawn.

## Installed Locally

- FModel `dec-2025`: `tools/FModel/current/FModel.exe`
- UE4SS / RE-UE4SS `v3.0.1`: `tools/UE4SS/current/`
- LiteNetLib `2.1.2`: installed as a NuGet package in `server/CyrodiilMP.Server`
