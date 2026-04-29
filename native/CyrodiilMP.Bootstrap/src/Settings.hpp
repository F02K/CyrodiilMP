#pragma once

#include <filesystem>

namespace CyrodiilMP::Bootstrap {

struct BootstrapSettings
{
    bool enable_debug_console = true;
    bool enable_ue_pattern_scan = true;
    bool enable_nirnlab_ui = true;
    bool show_main_menu_button = true;
};

BootstrapSettings LoadSettings(const std::filesystem::path& settings_path);
void EnsureSettingsFile(const std::filesystem::path& settings_path);

}
