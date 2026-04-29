#pragma once

#include <Mod/CppUserModBase.hpp>
#include <atomic>

namespace CyrodiilMP {

class GameHostMod : public RC::CppUserModBase {
public:
    GameHostMod();
    ~GameHostMod() override;

    // Called once when UE4SS initialises Unreal Engine access.
    // Safe to call UObjectGlobals and register hooks here.
    auto on_unreal_init() -> void override;

    // Called every game frame.
    // Used to poll for button injection readiness and drain the event queue.
    auto on_update() -> void override;

private:
    std::atomic<bool> m_buttonInjected{false};
    std::atomic<bool> m_hooksRegistered{false};
    std::atomic<bool> m_uiInitialized{false};
};

} // namespace CyrodiilMP
