#pragma once

#include <filesystem>

namespace CyrodiilMP::Bootstrap {

struct UiRuntimeSettings
{
    std::filesystem::path root_directory;
    std::filesystem::path game_client_directory;
    std::filesystem::path ui_directory;
    bool show_main_menu_button = true;
};

class UiRuntime
{
public:
    static UiRuntime& Instance();

    bool Initialize(UiRuntimeSettings settings);
    void ShowMainMenuButton();
    void Shutdown();
};

}
