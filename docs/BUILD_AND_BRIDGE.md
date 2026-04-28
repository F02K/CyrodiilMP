# Build And Client Bridge

CyrodiilMP now has one organized .NET build path and a small client bridge for the first main-menu connect MVP.

## Projects

- `shared/CyrodiilMP.Protocol` - shared constants and packet text builders.
- `server/CyrodiilMP.Server` - LiteNetLib dedicated server listener.
- `client/CyrodiilMP.ClientBridge` - short-lived client launched by the UE4SS Lua click hook.
- `tests/CyrodiilMP.NetProbe` - manual fake transform sender.
- `dashboard/CyrodiilMP.Dashboard` - local inspection dashboard.

## Build

```powershell
.\scripts\build.cmd -Configuration Debug
```

The root build script restores and builds each project in dependency order.

## Publish The Client Bridge

```powershell
.\scripts\publish-client-bridge.cmd
```

Output:

```text
artifacts\publish\client-bridge
```

## Install Game-Side UE4SS Mods And Bridge

```powershell
.\scripts\install-cyrodiilmp-ue4ss-mods.cmd
```

This installs:

- UE4SS Lua mods into `OblivionRemastered\Binaries\Win64\Mods`
- `CyrodiilMP.ClientBridge.exe` into `OblivionRemastered\Binaries\Win64\CyrodiilMP\ClientBridge`

If the game path is correct but the `Mods` or `CyrodiilMP\ClientBridge` folders do not exist yet, the installer now creates them automatically.

## MVP Flow

1. Start the dedicated server:

   ```powershell
   .\scripts\run-server.cmd -Port 27015
   ```

2. Start Oblivion Remastered and click the temporary Credits hook.
3. UE4SS Lua writes `connect-request.md`.
4. UE4SS Lua launches `CyrodiilMP\ClientBridge\CyrodiilMP.ClientBridge.exe`.
5. The bridge connects to `127.0.0.1:27015` and sends:

   ```text
   hello name=OblivionMenu source=ue4ss-menu protocol=0
   menu-connect name=OblivionMenu reason=<click reason>
   ```

6. The server responds with:

   ```text
   server-welcome player=<peer id> tick_rate=15 protocol=0
   menu-connect-ack player=<peer id> status=received
   ```

7. The bridge writes `client-bridge-result.json` in `CyrodiilMP_MenuProbe`.

This is still not the final in-process client. It is the clean first bridge from UI click to real round-trip server communication.
