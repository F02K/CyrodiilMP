#pragma once

#include <atomic>
#include <cstdint>
#include <filesystem>
#include <mutex>
#include <string>
#include <thread>

namespace CyrodiilMP::GameClient {

class CommandWatcher
{
public:
    static CommandWatcher& Instance();

    int Start(std::string command_dir, std::string host, uint16_t port);
    void Stop();

private:
    CommandWatcher() = default;
    ~CommandWatcher();

    void Run();
    void ProcessConnectRequest(const std::filesystem::path& request_path);
    void WriteTextFile(const std::filesystem::path& path, const std::string& text) const;

    std::mutex mutex;
    std::thread worker;
    std::atomic<bool> stop_requested{false};
    std::filesystem::path directory;
    std::string server_host = "127.0.0.1";
    uint16_t server_port = 27016;
};

}
