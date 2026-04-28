#include "ButtonInjector.hpp"

#include <DynamicOutput/DynamicOutput.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UFunction.hpp>
#include <Unreal/FName.hpp>
#include <Unreal/FString.hpp>
#include <Unreal/FText.hpp>

#include <vector>

namespace CyrodiilMP::ButtonInjector {

static constexpr auto TEXT_BLOCK_CLASS = STR("TextBlock");
static constexpr auto CREDITS_SLOT = STR("main_credits_wrapper");
static constexpr auto SET_TEXT_FN = STR("SetText");
static constexpr auto MULTIPLAYER_LABEL = STR("MULTIPLAYER");

static bool s_relabelled = false;

static bool IsCreditsTextBlock(RC::Unreal::UObject* object)
{
    if (!object)
    {
        return false;
    }

    const auto full_name = object->GetFullName();
    return full_name.find(CREDITS_SLOT) != std::wstring::npos;
}

static bool CallSetText(RC::Unreal::UObject* text_block)
{
    auto* set_text = text_block->GetFunctionByName(SET_TEXT_FN);
    if (!set_text)
    {
        return false;
    }

    struct SetTextParams
    {
        RC::Unreal::FText InText;
    } params{RC::Unreal::FText::FromString(RC::Unreal::FString(MULTIPLAYER_LABEL))};

    text_block->ProcessEvent(set_text, &params);
    return true;
}

bool TryInject()
{
    if (s_relabelled)
    {
        return true;
    }

    std::vector<RC::Unreal::UObject*> text_blocks;
    text_blocks.reserve(64);
    RC::Unreal::UObjectGlobals::FindAllOf(RC::Unreal::FName(TEXT_BLOCK_CLASS, FNAME_Add), text_blocks);

    if (text_blocks.empty())
    {
        return false;
    }

    int relabelled_count = 0;
    for (auto* text_block : text_blocks)
    {
        if (!IsCreditsTextBlock(text_block))
        {
            continue;
        }

        if (CallSetText(text_block))
        {
            ++relabelled_count;
        }
    }

    if (relabelled_count <= 0)
    {
        return false;
    }

    s_relabelled = true;
    RC::Output::send<RC::LogLevel::Normal>(
        STR("[CyrodiilMP.GameHost] Credits button relabelled to MULTIPLAYER by native DLL\n"));
    return true;
}

} // namespace CyrodiilMP::ButtonInjector
