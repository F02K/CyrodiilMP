#include "Log.hpp"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace CyrodiilMP::Bootstrap {

std::mutex Log::mutex;
std::filesystem::path Log::path = "CyrodiilMP/Bootstrap/Bootstrap.log";
bool Log::console_echo = false;

void Log::Initialize(const std::filesystem::path& new_path)
{
    std::scoped_lock lock(mutex);
    path = new_path;
    std::filesystem::create_directories(path.parent_path());
}

void Log::SetConsoleEcho(bool enabled)
{
    std::scoped_lock lock(mutex);
    console_echo = enabled;
}

void Log::Write(const std::string& message)
{
    std::scoped_lock lock(mutex);
    std::filesystem::create_directories(path.parent_path());

    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);
    std::tm local_time{};
    localtime_s(&local_time, &time);

    std::ostringstream line;
    line << std::put_time(&local_time, "%Y-%m-%d %H:%M:%S") << " " << message << "\n";

    std::ofstream stream(path, std::ios::app);
    stream << line.str();

    if (console_echo)
    {
        auto* output = GetStdHandle(STD_OUTPUT_HANDLE);
        if (output != nullptr && output != INVALID_HANDLE_VALUE)
        {
            DWORD written = 0;
            const auto text = line.str();
            WriteConsoleA(output, text.c_str(), static_cast<DWORD>(text.size()), &written, nullptr);
        }
    }
}

const std::filesystem::path& Log::Path()
{
    return path;
}

}
