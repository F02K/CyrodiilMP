# UI Platform Integration

CyrodiilMP owns a small UI API boundary in `native/CyrodiilMP.GameHost/src/UiRuntime.*`.
The NirnLabUIPlatform source is vendored under `vendor/NirnLabUIPlatform` and should plug in behind that boundary instead of becoming a direct dependency of gameplay or networking code.

## Current Slice

- `CyrodiilMP.GameHost` initializes `UiRuntime` during `on_unreal_init`.
- The MULTIPLAYER main-menu click asks `UiRuntime` to show `cyrodiilmp.main-menu`.
- Until an interactive backend is present, the click keeps the existing bridge fallback.
- Static web assets live in `game-plugin/UI/cyrodiilmp`.
- The installer copies those assets to `OblivionRemastered/Binaries/Win64/CyrodiilMP/UI`.
- NirnLabUIPlatform is tracked as a local source fork with Oblivion Remastered patch notes in `vendor/NirnLabUIPlatform/OBLIVION_REMASTERED.md`.

## Runtime Contract

The native side exposes these operations:

- initialize and shut down the UI backend
- create, show, hide, and tick named views
- send native events to JavaScript
- register JavaScript commands that dispatch back to C++

The first JavaScript commands are:

- `cyrodiilmp.connect`
- `cyrodiilmp.disconnect` (registered as a stub until GameHost calls GameClient directly)
- `cyrodiilmp.close`

## Host Detection

The vendored NirnLab API now includes `NirnLabUIPlatformAPI/Host.h`.
This lets code distinguish between upstream Skyrim/SKSE and a general Oblivion
Remastered implementation.

- Upstream-style builds define `NL_UI_HOST_SKYRIM_SKSE`.
- Oblivion Remastered-backed builds should define `NL_UI_HOST_OBLIVION_REMASTERED`.
- Consumers can call the optional `GetUIPlatformHostInfo()` export through
  `DllLoader`, or use `APIMessageType::RequestHostInfo` in message-based integrations.

## NirnLab Backend Checklist

Before replacing the placeholder backend:

- preserve upstream MIT license and credits
- separate generic CEF code from Skyrim/SKSE-specific code
- verify render hook compatibility with Oblivion Remastered's renderer path
- map cursor and keyboard focus to UE5/CommonUI behavior
- make CEF subprocess cleanup reliable on normal exit and crash exit
- decide where backend binaries and CEF resources are version-pinned

## Target Flow

```text
MULTIPLAYER click
  -> GameHost HookManager
  -> UiRuntime.ShowView("cyrodiilmp.main-menu")
  -> HTML/JS connect form
  -> JS command "cyrodiilmp.connect"
  -> GameHost command handler
  -> GameClient C ABI
  -> server connect/status
  -> UiRuntime.SendEvent("statusChanged", ...)
```
