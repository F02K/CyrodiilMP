#include "ButtonInjector.hpp"

#include <DynamicOutput/DynamicOutput.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UClass.hpp>
#include <Unreal/UFunction.hpp>
#include <Unreal/FString.hpp>
#include <Unreal/FText.hpp>

namespace CyrodiilMP::ButtonInjector {

// ── Confirmed from RuntimeInspector runtime dump ──────────────────────────────

// The panel that holds all main-menu buttons.
static constexpr auto LAYOUT_CLASS_SHORT =
    STR("WBP_Modern_MainMenu_ButtonLayout_C");

// Full Blueprint asset path for a single button wrapper widget.
static constexpr auto BUTTON_WRAPPER_PATH =
    STR("/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C");

// Blueprint static library for CreateWidget.
static constexpr auto WIDGET_LIBRARY_PATH =
    STR("/Script/UMG.WidgetBlueprintLibrary");

// Name we give the new widget so HookManager can identify its clicks.
static constexpr auto INJECTED_WIDGET_NAME =
    STR("cyrodiilmp_multiplayer");

// ── Helpers ───────────────────────────────────────────────────────────────────

// Call UWidgetBlueprintLibrary::Create(WorldContextObject, WidgetType) via
// ProcessEvent on the CDO.  Returns the new UUserWidget* or nullptr.
static RC::Unreal::UObject* CallCreateWidget(RC::Unreal::UObject* worldContext,
                                              RC::Unreal::UClass*  widgetClass)
{
    auto* libClass = RC::Unreal::UObjectGlobals::StaticFindObject<RC::Unreal::UClass*>(
        nullptr, nullptr, WIDGET_LIBRARY_PATH);
    if (!libClass) return nullptr;

    auto* cdo = libClass->GetDefaultObject();
    if (!cdo) return nullptr;

    auto* createFn = libClass->FindFunction(STR("Create"));
    if (!createFn) return nullptr;

    // Params layout must match the Blueprint function signature exactly.
    struct CreateParams {
        RC::Unreal::UObject* WorldContextObject{nullptr};
        RC::Unreal::UClass*  WidgetType{nullptr};
        RC::Unreal::UObject* ReturnValue{nullptr};
    } params;
    params.WorldContextObject = worldContext;
    params.WidgetType         = widgetClass;

    cdo->ProcessEvent(createFn, &params);
    return params.ReturnValue;
}

// Call UPanelWidget::AddChild(Content) via ProcessEvent.
static void CallAddChild(RC::Unreal::UObject* panel,
                          RC::Unreal::UObject* child)
{
    auto* addChildFn = panel->GetFunctionByName(STR("AddChild"));
    if (!addChildFn) return;

    struct AddChildParams {
        RC::Unreal::UObject* Content{nullptr};
        RC::Unreal::UObject* ReturnValue{nullptr};
    } params;
    params.Content = child;
    panel->ProcessEvent(addChildFn, &params);
}

// Set a FText property by name via reflection.
// Tries both "ButtonText" and "LabelText" since the exact property name in
// the Blueprint is not yet confirmed — update once the Blueprint is inspected.
static void TrySetButtonText(RC::Unreal::UObject* widget, std::wstring_view text)
{
    static constexpr std::wstring_view candidates[] = {
        STR("ButtonText"),
        STR("LabelText"),
        STR("Text"),
    };

    for (auto propName : candidates)
    {
        auto* ptr = widget->GetValuePtrByPropertyNameInChain<RC::Unreal::FText>(
            propName.data());
        if (ptr)
        {
            // FText construction via the Unreal string table.
            // FText::FromString is the simplest factory available at runtime.
            *ptr = RC::Unreal::FText::FromString(RC::Unreal::FString(text.data()));
            return;
        }
    }

    RC::Output::send<RC::LogLevel::Warning>(
        STR("[CyrodiilMP.GameHost] ButtonInjector: no text property found on new button widget\n"));
}

// ── Public API ────────────────────────────────────────────────────────────────

static bool s_injected = false;

bool TryInject()
{
    if (s_injected) return true;

    // The layout panel must be alive (i.e. the main menu is showing).
    auto* layout = RC::Unreal::UObjectGlobals::FindFirstOf(LAYOUT_CLASS_SHORT);
    if (!layout) return false;

    // Resolve the button wrapper Blueprint class.
    auto* btnClass = RC::Unreal::UObjectGlobals::StaticFindObject<RC::Unreal::UClass*>(
        nullptr, nullptr, BUTTON_WRAPPER_PATH);
    if (!btnClass)
    {
        RC::Output::send<RC::LogLevel::Warning>(
            STR("[CyrodiilMP.GameHost] ButtonInjector: WBP_MainMenu_Button_Wrapper_C not found\n"));
        return false;
    }

    // Create the new widget instance.
    auto* newBtn = CallCreateWidget(layout, btnClass);
    if (!newBtn)
    {
        RC::Output::send<RC::LogLevel::Warning>(
            STR("[CyrodiilMP.GameHost] ButtonInjector: CreateWidget returned nullptr\n"));
        return false;
    }

    // Rename the widget so our hook can identify clicks on it.
    newBtn->SetFName(RC::Unreal::FName(INJECTED_WIDGET_NAME));

    // Set the button label to "MULTIPLAYER".
    TrySetButtonText(newBtn, STR("MULTIPLAYER"));

    // Add to the layout panel.
    CallAddChild(layout, newBtn);

    s_injected = true;
    return true;
}

} // namespace CyrodiilMP::ButtonInjector
