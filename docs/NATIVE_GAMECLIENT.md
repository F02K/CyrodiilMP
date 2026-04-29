# Native GameClient

`CyrodiilMP.GameClient` is a standalone native C++ DLL. It does not depend on RE-UE4SS.

This is the replacement path for making the real client runtime native while keeping UE4SS Lua/C++ only as loaders and research tooling.

## Build

```powershell
.\scripts\build-native.cmd -Configuration Release
```

Default native build now builds:

- `CyrodiilMP.GameClient.dll`
- `CyrodiilMP.GameClient.Host.exe`

Output:

```text
artifacts\native\Release\GameClient
```

To also build the UE4SS C++ GameHost mod, pass:

```powershell
.\scripts\build-native.cmd -Configuration Release -BuildUe4ssGameHost
```

That optional path still requires RE-UE4SS source.

## Install

Build the native GameClient first:

```powershell
.\scripts\build-native.cmd -Configuration Release
```

Then install the UE4SS research tooling and copy the GameClient into the game folder:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

The installer does not require or warn about the optional UE4SS C++ GameHost. To install that experimental path later, pass:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd -IncludeUe4ssGameHost
```

## Game Startup Loading

`CyrodiilMP.GameClient.dll` does not load itself just because it exists in the game folder. The UE4SS Lua bootstrap loads it with `package.loadlib` from:

```text
OblivionRemastered\Binaries\Win64\CyrodiilMP\GameClient\CyrodiilMP.GameClient.dll
```

The DLL exports `luaopen_CyrodiilMP_GameClient`, which starts the GameClient menu command watcher. The UE4SS Lua bootstrap only loads the DLL. UI edits, including Credits -> Multiplayer, belong in the native UE4SS GameHost path because the packaged UE4SS runtime does not export the Lua C API needed for a plain DLL to safely call UE4SS Lua functions itself.

## First Native Server Proof

The native client currently talks to the server's raw UDP sidecar, not LiteNetLib. This avoids pretending a raw Winsock client can speak LiteNetLib's handshake protocol.

Start the server:

```powershell
.\scripts\run-server.cmd -Port 27015
```

The server also opens native UDP sidecar port `27016`.

Then run:

```powershell
.\scripts\run-native-gameclient.cmd -Port 27016
```

Expected client message:

```text
connected=1 error=0 message="native-welcome status=ok protocol=0"
```

Expected server log:

```text
native-udp packet endpoint=... text="native-hello name=NativeManual reason=manual-native-test protocol=0"
```

## C ABI

The DLL exports:

```cpp
int CyrodiilMP_Initialize(const char* log_path);
int CyrodiilMP_Connect(const CyrodiilMP_ConnectOptions* options);
void CyrodiilMP_Disconnect();
int CyrodiilMP_IsConnected();
void CyrodiilMP_GetStatus(CyrodiilMP_ClientStatus* status);
const char* CyrodiilMP_GetVersion();
```

Next loader options:

- Call these exports from a UE4SS C++ GameHost once RE-UE4SS is available.
- Load the DLL through a small custom loader/proxy later.
- Keep Lua only as a temporary launcher while C++ ownership grows.
