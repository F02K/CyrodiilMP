#pragma once

#include <filesystem>

namespace CyrodiilMP::Bootstrap {

struct BootstrapSettings
{
    bool enable_ue_pattern_scan = true;
};

BootstrapSettings LoadSettings(const std::filesystem::path& settings_path);
void EnsureSettingsFile(const std::filesystem::path& settings_path);

}
