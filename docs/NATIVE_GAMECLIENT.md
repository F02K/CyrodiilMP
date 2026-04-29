# Native GameClient

`CyrodiilMP.GameClient` is a standalone native C++ DLL. It does not depend on RE-UE4SS.

This is the runtime client path. UE4SS is research/dumper tooling only and should not load or own the real client.

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

## Install

Build the native GameClient first:

```powershell
.\scripts\build-native.cmd -Configuration Release
```

Then install the standalone loader path:

```powershell
.\scripts\install-standalone-loader.cmd -Configuration Release
```

Install UE4SS research helpers separately only when collecting dumps or runtime data:

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

## Game Startup Loading

`CyrodiilMP.GameClient.dll` does not load itself just because it exists in the game folder. The standalone bootstrap loads it from:

```text
OblivionRemastered\Binaries\Win64\CyrodiilMP\GameClient\CyrodiilMP.GameClient.dll
```

The old `luaopen_CyrodiilMP_GameClient` export remains for historical smoke tests, but it is not the runtime loading path.

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

- Call these exports from `CyrodiilMP.Bootstrap`.
- Add UI/NirnLab command routing in an owned native module.
- Keep UE4SS out of runtime loading.
