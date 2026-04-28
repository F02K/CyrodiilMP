#include "Log.hpp"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace CyrodiilMP::Bootstrap {

std::mutex Log::mutex;
std::filesystem::path Log::path = "CyrodiilMP/Bootstrap/Bootstrap.log";

void Log::Initialize(const std::filesystem::path& new_path)
{
    std::scoped_lock lock(mutex);
    path = new_path;
    std::filesystem::create_directories(path.parent_path());
}

void Log::Write(const std::string& message)
{
    std::scoped_lock lock(mutex);
    std::filesystem::create_directories(path.parent_path());

    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);
    std::tm local_time{};
    localtime_s(&local_time, &time);

    std::ofstream stream(path, std::ios::app);
    stream << std::put_time(&local_time, "%Y-%m-%d %H:%M:%S") << " " << message << "\n";
}

const std::filesystem::path& Log::Path()
{
    return path;
}

}
