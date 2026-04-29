#include "UiRuntime.hpp"

#include <DynamicOutput/DynamicOutput.hpp>

#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>

namespace CyrodiilMP::UiRuntime {
namespace {

struct ViewState
{
    std::string asset_path;
    bool visible{false};
};

std::mutex s_mutex;
bool s_initialized{false};
bool s_interactive_backend{false};
Config s_config{};
std::unordered_map<std::string, ViewState> s_views;
std::unordered_map<std::string, CommandHandler> s_commands;

void Log(std::wstring_view message)
{
    RC::Output::send<RC::LogLevel::Normal>(STR("[CyrodiilMP.GameHost] "));
    RC::Output::send<RC::LogLevel::Normal>(message.data());
    RC::Output::send<RC::LogLevel::Normal>(STR("\n"));
}

} // namespace

std::string_view MainMenuViewId()
{
    return "cyrodiilmp.main-menu";
}

bool Initialize(const Config& config)
{
    std::scoped_lock lock{s_mutex};
    if (s_initialized)
    {
        return true;
    }

    s_config = config;

    // This placeholder keeps the CyrodiilMP API stable while NirnLab/CEF
    // portability is verified. Set this true only when a real backend is wired.
    s_interactive_backend = false;
    s_initialized = true;

    Log(STR("UI runtime initialized with placeholder backend"));
    return true;
}

void Shutdown()
{
    std::scoped_lock lock{s_mutex};
    if (!s_initialized)
    {
        return;
    }

    s_commands.clear();
    s_views.clear();
    s_initialized = false;
    s_interactive_backend = false;
    Log(STR("UI runtime shutdown"));
}

void Tick()
{
    std::scoped_lock lock{s_mutex};
    if (!s_initialized || !s_interactive_backend)
    {
        return;
    }

    // Future NirnLab/CEF backend tick goes here.
}

bool HasInteractiveBackend()
{
    std::scoped_lock lock{s_mutex};
    return s_initialized && s_interactive_backend;
}

bool CreateView(std::string_view id, std::string_view asset_path)
{
    std::scoped_lock lock{s_mutex};
    if (!s_initialized || id.empty())
    {
        return false;
    }

    auto& view = s_views[std::string{id}];
    view.asset_path = std::string{asset_path};
    return true;
}

bool ShowView(std::string_view id)
{
    std::scoped_lock lock{s_mutex};
    auto it = s_views.find(std::string{id});
    if (!s_initialized || it == s_views.end())
    {
        return false;
    }

    it->second.visible = true;
    Log(STR("UI view show requested"));
    return true;
}

bool HideView(std::string_view id)
{
    std::scoped_lock lock{s_mutex};
    auto it = s_views.find(std::string{id});
    if (!s_initialized || it == s_views.end())
    {
        return false;
    }

    it->second.visible = false;
    return true;
}

bool IsViewVisible(std::string_view id)
{
    std::scoped_lock lock{s_mutex};
    auto it = s_views.find(std::string{id});
    return s_initialized && it != s_views.end() && it->second.visible;
}

bool SendEvent(std::string_view, std::string_view)
{
    std::scoped_lock lock{s_mutex};
    return s_initialized && s_interactive_backend;
}

void RegisterCommand(std::string command_name, CommandHandler handler)
{
    std::scoped_lock lock{s_mutex};
    if (command_name.empty() || !handler)
    {
        return;
    }

    s_commands.insert_or_assign(std::move(command_name), std::move(handler));
}

bool DispatchCommand(std::string_view command_name, std::string_view payload_json)
{
    CommandHandler handler;
    {
        std::scoped_lock lock{s_mutex};
        auto it = s_commands.find(std::string{command_name});
        if (!s_initialized || it == s_commands.end())
        {
            return false;
        }

        handler = it->second;
    }

    handler(payload_json);
    return true;
}

} // namespace CyrodiilMP::UiRuntime
