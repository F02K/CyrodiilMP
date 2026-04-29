#pragma once

#include <filesystem>

namespace CyrodiilMP::Bootstrap {

struct UEBridgeSettings
{
    bool enable_pattern_scan = true;
    std::filesystem::path output_directory;
};

class UEBridge
{
public:
    static void Initialize(const std::filesystem::path& game_exe_path, UEBridgeSettings settings);
    static void CaptureStartupSnapshot();
};

}
