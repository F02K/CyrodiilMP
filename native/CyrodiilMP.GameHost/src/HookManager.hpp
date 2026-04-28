#pragma once

namespace CyrodiilMP::HookManager {

// Register all UE5 ProcessEvent hooks.
// Must be called from GameHostMod::on_unreal_init().
void RegisterHooks();

} // namespace CyrodiilMP::HookManager
