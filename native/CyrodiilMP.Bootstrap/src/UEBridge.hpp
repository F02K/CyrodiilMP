#pragma once

#include <filesystem>

namespace CyrodiilMP::Bootstrap {

class UEBridge
{
public:
    static void Initialize(const std::filesystem::path& game_exe_path);
    static void CaptureStartupSnapshot();
};

}
