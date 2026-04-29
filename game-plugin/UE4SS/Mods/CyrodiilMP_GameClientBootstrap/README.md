# CyrodiilMP GameClient Bootstrap

Small UE4SS Lua bootstrap for the standalone native GameClient.

Responsibilities:

- Load `CyrodiilMP.GameClient.dll`.
- Write `Win64\CyrodiilMP\GameClient\bootstrap-status.txt`.

All game/UI behavior must live in native DLL code. This Lua file is intentionally only a loader.
