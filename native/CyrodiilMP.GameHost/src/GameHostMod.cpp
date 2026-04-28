#include "../include/GameHostMod.hpp"
#include "ButtonInjector.hpp"
#include "BridgeLauncher.hpp"
#include "HookManager.hpp"

#include <DynamicOutput/DynamicOutput.hpp>

namespace CyrodiilMP {

GameHostMod::GameHostMod()
{
    ModName        = STR("CyrodiilMP.GameHost");
    ModVersion     = STR("0.1.0");
    ModDescription = STR("CyrodiilMP native game host: button injection, hooks, bridge launcher, scripting ABI.");
    ModAuthors     = STR("CyrodiilMP");
}

auto GameHostMod::on_unreal_init() -> void
{
    RC::Output::send<RC::LogLevel::Normal>(STR("[CyrodiilMP.GameHost] on_unreal_init\n"));

    HookManager::RegisterHooks();
    m_hooksRegistered = true;

    RC::Output::send<RC::LogLevel::Normal>(STR("[CyrodiilMP.GameHost] hooks registered\n"));
}

auto GameHostMod::on_update() -> void
{
    // Attempt button injection each frame until it succeeds.
    // ButtonInjector::TryInject() is a no-op once it has succeeded.
    if (!m_buttonInjected.load(std::memory_order_relaxed))
    {
        if (ButtonInjector::TryInject())
        {
            m_buttonInjected.store(true, std::memory_order_relaxed);
            RC::Output::send<RC::LogLevel::Normal>(
                STR("[CyrodiilMP.GameHost] MULTIPLAYER button injected\n"));
        }
    }

    // Drain results posted by the bridge launcher background thread and fire
    // any pending scripting events (e.g. connect.succeeded → open level).
    BridgeLauncher::DrainResultQueue();
}

} // namespace CyrodiilMP
