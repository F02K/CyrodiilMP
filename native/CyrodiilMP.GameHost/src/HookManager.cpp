#include "HookManager.hpp"
#include "BridgeLauncher.hpp"
#include "UiRuntime.hpp"

#include <DynamicOutput/DynamicOutput.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UFunction.hpp>
#include <Unreal/Hook.hpp>

namespace CyrodiilMP::HookManager {

// Widget full-name substring that identifies our repurposed MULTIPLAYER slot.
static constexpr auto CREDITS_SLOT      = STR("main_credits_wrapper");
static constexpr auto HANDLE_CLICKED_FN = STR("HandleButtonClicked");

static bool IsMultiplayerClick(RC::Unreal::UObject* context,
                                RC::Unreal::UFunction* function)
{
    if (!function) return false;

    // Fast-path: only look at HandleButtonClicked calls.
    auto funcName = function->GetFullName();
    if (funcName.find(HANDLE_CLICKED_FN) == std::wstring::npos) return false;

    if (!context) return false;
    auto widgetName = context->GetFullName();
    return widgetName.find(CREDITS_SLOT) != std::wstring::npos;
}

void RegisterHooks()
{
    // RegisterProcessEventPreCallback fires before every UObject::ProcessEvent
    // call.  We filter down to just the button click we care about.
    //
    // NOTE: If the UE4SS version exposes a per-function-path hook API, prefer
    // that — it is cheaper than the global callback.  At UE4SS v3.0.1 the
    // global callback is the documented C++ API.
    RC::Unreal::Hook::RegisterProcessEventPreCallback(
        [](RC::Unreal::UObject* context,
           RC::Unreal::UFunction* function,
           void* /*params*/) -> void
        {
            if (IsMultiplayerClick(context, function))
            {
                RC::Output::send<RC::LogLevel::Normal>(
                    STR("[CyrodiilMP.GameHost] MULTIPLAYER button clicked\n"));
                const auto ui_opened = UiRuntime::ShowView(UiRuntime::MainMenuViewId());
                if (!ui_opened || !UiRuntime::HasInteractiveBackend())
                {
                    RC::Output::send<RC::LogLevel::Normal>(
                        STR("[CyrodiilMP.GameHost] UI backend unavailable; launching bridge fallback\n"));
                    BridgeLauncher::LaunchAsync();
                }
            }
        });
}

} // namespace CyrodiilMP::HookManager
