# CyrodiilMP Dashboard

The dashboard is now a browser-based helper for the tooling already in this repo. It is meant to reduce terminal hopping while doing repeated research and smoke-test passes.

## Run

The foreground launcher uses `dotnet run`, so it requires a local .NET SDK. The background launcher needs a built dashboard DLL plus a local .NET runtime.

Foreground:

```powershell
.\scripts\run-dashboard.cmd -Port 5088
```

Background:

```powershell
.\scripts\start-dashboard-background.cmd -Port 5088
```

Stop background process:

```powershell
.\scripts\stop-dashboard.cmd
```

Then open:

```text
http://127.0.0.1:5088
```

## What It Helps With

- Save or clear the local `game-path.txt` value from the browser.
- Detect whether the UE4SS helper mods and published client bridge are already installed into the local game folder, then run the installer from the browser when needed.
- Start helper jobs for:
  - quick scan
  - full research
  - new research notes runs
  - runtime dump collection
  - runtime dump analysis
  - client-bridge smoke tests
  - UE4SS helper mod installation
- Track the current dashboard job and inspect recent captured logs.
- Start and stop the helper-managed local server process, inspect its captured log output, and force-kill lingering `CyrodiilMP.Server` processes if a normal stop gets stuck.
- Browse generated artifacts without leaving the browser:
  - `research/game-inventory`
  - `research/full-research`
  - `research/runs`
  - `research/runtime-dumps`

## Notes

- The dashboard only reads or launches local tooling already present in this repo.
- It does not extract or serve proprietary game assets.
- The UE4SS install helper will create the missing `Win64\Mods` and `CyrodiilMP\ClientBridge` folders automatically when the saved game path looks like a valid Oblivion Remastered install root.
- The server control is intentionally narrow: it only manages the local `scripts/run-server.ps1` workflow for smoke testing.
- `Force Kill Server` is a recovery action. It looks for matching `CyrodiilMP.Server` processes on the local machine and terminates them even if they were not started by the current dashboard session.
- Some actions still depend on the local machine being able to run the underlying scripts, including `dotnet` for the server and bridge helpers.
- The helper job runner allows one active dashboard job at a time so the captured logs stay readable.
