# NirnLabUIPlatform Oblivion Remastered Patch

This directory vendors the MIT-licensed upstream source from:

```text
https://github.com/kkEngine/NirnLabUIPlatform
```

Fork point:

```text
main, shallow clone taken for CyrodiilMP integration work on 2026-04-29
```

## Integration Goal

This fork should become a general Oblivion Remastered host implementation for
NirnLabUIPlatform. CyrodiilMP is the first local consumer, but host detection,
runtime naming, and API surface should describe the game/runtime host rather
than the CyrodiilMP mod.

CyrodiilMP game/runtime code should talk to
`native/CyrodiilMP.GameHost/src/UiRuntime.*`; this vendor fork should sit behind
that boundary as the Chromium backend.

## Expected Porting Work

- Remove or isolate SKSE and CommonLibSSE entry points.
- Replace Skyrim native-menu assumptions with UE5/UE4SS or standalone hook
  equivalents.
- Keep the reusable CEF pieces: browser lifetime, subprocess management,
  JavaScript callbacks, native-to-JS events, and CEF resource packaging.
- Replace Skyrim key-code and cursor handling with Oblivion Remastered input focus
  routing.
- Rename runtime output paths from `Data/NirnLabUIPlatform` to an Oblivion
  Remastered-compatible path under `Binaries/Win64`.

## Initial Source Triage

Likely reusable with minimal game-specific work:

- `src/CEFSubprocess`
- `src/UIPlatform/CEF`
- `src/UIPlatform/JS`
- `src/UIPlatform/Converters`
- `src/UIPlatform/Providers`
- `src/UIPlatform/Services/CEFService.*`

Skyrim/SKSE-specific and expected to need replacement or adapters:

- `src/UIPlatform/main.cpp`
- `src/UIPlugin`
- `src/UIPlatformTest`
- `src/UIPlatform/Menus`
- `src/UIPlatform/Services/UIPlatformService.*`
- `src/UIPlatform/Services/InputLangSwitchService.*`
- `src/UIPlatform/Converters/KeyInputConverter.*`
- code using `SKSE::`, `RE::`, `REL::`, `CommonLibSSE`, or Address Library

DirectX 11 rendering is present in the upstream CMake and render layer code.
Oblivion Remastered's actual renderer path still needs confirmation before we
choose between porting the existing D3D11 render layer, adapting it for another
swapchain path, or rendering through a UE/UE4SS surface.

## First Adapter Target

`UiRuntime` should eventually map to the public NirnLab-style API:

- `CreateView` -> `IUIPlatformAPI::AddOrGetBrowser`
- `HideView` / `ShowView` -> `IBrowser::SetBrowserVisible`
- `SendEvent` -> `IBrowser::ExecEventFunction`
- UI command registration -> `IBrowser::AddFunctionCallback`

Keep changes small and documented so we can still compare this fork with
upstream when useful.

## Host Detection Contract

This fork adds `src/UIPlatform/NirnLabUIPlatformAPI/Host.h`.

Consumers can detect which runtime provides the UI platform by either:

- calling the optional DLL export `GetUIPlatformHostInfo()` through
  `DllLoader::GetUIPlatformHostInfo()`
- dispatching `APIMessageType::RequestHostInfo` and reading
  `ResponseHostInfoMessage::hostInfo`

Known host values:

- `NL::UI::HostRuntime::SkyrimSKSE`
- `NL::UI::HostRuntime::OblivionRemastered`

The upstream Skyrim build defines `NL_UI_HOST_SKYRIM_SKSE`. An Oblivion
Remastered-backed build should define `NL_UI_HOST_OBLIVION_REMASTERED`.

Example:

```cpp
auto host = NL::UI::DllLoader::GetUIPlatformHostInfo();
if (host.runtime == NL::UI::HostRuntime::OblivionRemastered)
{
    // Use Oblivion Remastered-specific setup.
}
else if (host.runtime == NL::UI::HostRuntime::SkyrimSKSE)
{
    // Use Skyrim/SKSE-specific setup.
}
```
