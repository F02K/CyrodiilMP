#pragma once

#include <functional>
#include <string>
#include <string_view>

namespace CyrodiilMP::UiRuntime {

struct Config
{
    std::string asset_root;
    std::string preferred_backend;
};

using CommandHandler = std::function<void(std::string_view payload_json)>;

std::string_view MainMenuViewId();

bool Initialize(const Config& config);
void Shutdown();
void Tick();

bool HasInteractiveBackend();
bool CreateView(std::string_view id, std::string_view asset_path);
bool ShowView(std::string_view id);
bool HideView(std::string_view id);
bool IsViewVisible(std::string_view id);

bool SendEvent(std::string_view event_name, std::string_view payload_json);
void RegisterCommand(std::string command_name, CommandHandler handler);
bool DispatchCommand(std::string_view command_name, std::string_view payload_json);

} // namespace CyrodiilMP::UiRuntime
