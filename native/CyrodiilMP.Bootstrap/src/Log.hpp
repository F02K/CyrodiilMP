#pragma once

#include <filesystem>
#include <mutex>
#include <string>

namespace CyrodiilMP::Bootstrap {

class Log
{
public:
    static void Initialize(const std::filesystem::path& path);
    static void Write(const std::string& message);
    static const std::filesystem::path& Path();

private:
    static std::mutex mutex;
    static std::filesystem::path path;
};

}
