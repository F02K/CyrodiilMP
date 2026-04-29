# UE4SS Research Role

UE4SS is a research and dumper tool in CyrodiilMP, not a runtime dependency.

Allowed uses:

- dump reflected objects, properties, names, and offsets
- generate or collect `.usmap` data
- inspect menus/widgets while the game is running
- cross-check provisional UE pattern scanner results

Out of scope for UE4SS:

- loading the real multiplayer client
- owning UI or NirnLab integration
- launching bridge/client processes
- handling gameplay networking
- shipping final gameplay behavior

Use `scripts/install-cyrodiilmp-ue4ss-mods.ps1` only to install research
helpers such as `CyrodiilMP_RuntimeInspector` and optional `CyrodiilMP_AutoUSMAP`.
