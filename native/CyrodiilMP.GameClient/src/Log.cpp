#include "Log.hpp"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace CyrodiilMP::GameClient {

std::mutex Log::mutex;
std::string Log::path = "CyrodiilMP/GameClient/GameClient.log";

void Log::Initialize(std::string new_path)
{
    std::scoped_lock lock(mutex);
    if (!new_path.empty())
    {
        path = std::move(new_path);
    }

    std::filesystem::create_directories(std::filesystem::path(path).parent_path());
}

void Log::Write(std::string message)
{
    std::scoped_lock lock(mutex);
    std::filesystem::create_directories(std::filesystem::path(path).parent_path());

    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    std::tm local_time{};
    localtime_s(&local_time, &time);

    std::ofstream stream(path, std::ios::app);
    stream << std::put_time(&local_time, "%Y-%m-%d %H:%M:%S") << " " << message << "\n";
}

}
