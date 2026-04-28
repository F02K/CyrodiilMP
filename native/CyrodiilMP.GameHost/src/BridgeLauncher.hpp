#pragma once

namespace CyrodiilMP::BridgeLauncher {

// Launch CyrodiilMP.ClientBridge.exe on a background thread.
// Returns immediately; result is delivered via ScriptingHost::FireEvent on the
// game thread during the next on_update() tick.
// Guards against concurrent launches — a second call while one is in flight
// is a no-op.
void LaunchAsync();

// Called by GameHostMod::on_update() to drain the result queue and fire
// any pending scripting events on the game thread.
void DrainResultQueue();

} // namespace CyrodiilMP::BridgeLauncher
