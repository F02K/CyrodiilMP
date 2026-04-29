# UI Platform Integration

CyrodiilMP owns a small UI API boundary for the standalone launcher/bootstrap path.
The NirnLabUIPlatformOR source is referenced as a submodule under `vendor/NirnLabUIPlatformOR` and should plug in behind that boundary instead of becoming a direct dependency of gameplay or networking code.

## Current Slice

- The previous UE4SS UI path was deleted with the retired C++ experiment.
- UI runtime work should move into the owned launcher/bootstrap native path.
- UE4SS may still be used for dumps and runtime inspection, but not for game UI ownership.
- Static web assets live in `game-plugin/UI/cyrodiilmp`.
- NirnLabUIPlatformOR points at the `F02K/NirnLabUIPlatformOR` fork on the `oblivion-remastered-host` branch. `OR` means Oblivion Remastered; Skyrim/SKSE compatibility is not a target for this fork.
- `CyrodiilMP.Bootstrap` now has a `UiRuntime` loader that looks for `CyrodiilMP/NirnLabUIPlatformOR/NirnLabUIPlatform.dll`, creates a Chromium-backed `MULTIPLAYER` button view, and routes button JavaScript commands back to the existing native GameClient command watcher.

## Main Menu Button Slice

Installed layout:

```text
OblivionRemastered/Binaries/Win64/CyrodiilMP/
  Bootstrap/settings.ini
  GameClient/
  NirnLabUIPlatformOR/NirnLabUIPlatform.dll
  UI/cyrodiilmp/main-menu-button.html
```

Bootstrap settings:

```ini
[Debug]
EnableConsole=true

[UI]
EnableNirnLabUI=true
ShowMainMenuButton=true
```

`EnableConsole` currently defaults to `true` so the standalone bootstrap opens a
native debug console and mirrors `Bootstrap.log` messages while the UI host is
being integrated. Set it to `false` to hide the console on the next launch.

The current button view is a first host integration slice. It proves that
Bootstrap can load NirnLabUIPlatformOR, create a browser, bind
`CyrodiilMP.invoke`, and write `connect-request.txt` for GameClient. The exact
UE main-menu widget anchoring still needs to be attached once the Oblivion
Remastered menu widget/function names are confirmed from runtime dumps.

## Runtime Contract

The native side exposes these operations:

- initialize and shut down the UI backend
- create, show, hide, and tick named views
- send native events to JavaScript
- register JavaScript commands that dispatch back to C++

The first JavaScript commands are:

- `cyrodiilmp.connect`
- `cyrodiilmp.disconnect`
- `cyrodiilmp.close`

## Host Detection

The vendored NirnLab API includes `NirnLabUIPlatformAPI/Host.h`.
This fork reports Oblivion Remastered as its only supported runtime host.

- Oblivion Remastered-backed builds define `NL_UI_HOST_OBLIVION_REMASTERED`.
- Consumers can call the optional `GetUIPlatformHostInfo()` export through
  `DllLoader`, or use `APIMessageType::RequestHostInfo` in message-based integrations.

## NirnLab Backend Checklist

Before replacing the placeholder backend:

- preserve upstream MIT license and credits
- separate generic CEF code from the remaining upstream Skyrim/SKSE scaffolding
- verify render hook compatibility with Oblivion Remastered's renderer path
- map cursor and keyboard focus to UE5/CommonUI behavior
- make CEF subprocess cleanup reliable on normal exit and crash exit
- decide where backend binaries and CEF resources are version-pinned

## Target Flow

```text
MULTIPLAYER click
  -> owned native launcher/bootstrap UI hook
  -> UiRuntime.ShowView("cyrodiilmp.main-menu")
  -> HTML/JS connect form
  -> JS command "cyrodiilmp.connect"
  -> native UI command handler
  -> GameClient C ABI
  -> server connect/status
  -> UiRuntime.SendEvent("statusChanged", ...)
```
