#include "CommandWatcher.hpp"

#include "Log.hpp"
#include "NetworkClient.hpp"

#include <CyrodiilMP/GameClientApi.h>

#include <chrono>
#include <fstream>
#include <sstream>
#include <thread>

namespace CyrodiilMP::GameClient {

namespace {

std::string Trim(std::string value)
{
    while (!value.empty() && (value.back() == '\r' || value.back() == '\n' || value.back() == ' ' || value.back() == '\t'))
    {
        value.pop_back();
    }

    size_t first = 0;
    while (first < value.size() && (value[first] == ' ' || value[first] == '\t'))
    {
        ++first;
    }

    return value.substr(first);
}

std::string ReadKey(const std::string& text, const std::string& key, const std::string& fallback)
{
    std::istringstream stream(text);
    std::string line;
    const auto prefix = key + "=";
    while (std::getline(stream, line))
    {
        line = Trim(line);
        if (line.rfind(prefix, 0) == 0)
        {
            auto value = Trim(line.substr(prefix.size()));
            return value.empty() ? fallback : value;
        }
    }

    return fallback;
}

}

CommandWatcher::~CommandWatcher()
{
    Stop();
}

CommandWatcher& CommandWatcher::Instance()
{
    static CommandWatcher instance;
    return instance;
}

int CommandWatcher::Start(std::string command_dir, std::string host, uint16_t port)
{
    Stop();

    {
        std::scoped_lock lock(mutex);
        directory = command_dir.empty() ? std::filesystem::path("CyrodiilMP/GameClient") : std::filesystem::path(std::move(command_dir));
        server_host = host.empty() ? "127.0.0.1" : std::move(host);
        server_port = port == 0 ? static_cast<uint16_t>(27016) : port;
        std::filesystem::create_directories(directory);
        WriteTextFile(directory / "menu-label.txt", "MULTIPLAYER\n");
        WriteTextFile(directory / "loader-status.txt", "loaded=1\nwatcher=starting\n");
    }

    stop_requested = false;
    worker = std::thread(&CommandWatcher::Run, this);
    Log::Write("menu command watcher started");
    return 0;
}

void CommandWatcher::Stop()
{
    stop_requested = true;
    if (worker.joinable())
    {
        worker.join();
    }
}

void CommandWatcher::Run()
{
    std::filesystem::path current_dir;
    std::string current_host;
    uint16_t current_port = 27016;
    {
        std::scoped_lock lock(mutex);
        current_dir = directory;
        current_host = server_host;
        current_port = server_port;
    }

    WriteTextFile(current_dir / "loader-status.txt",
        "loaded=1\nwatcher=running\nhost=" + current_host + "\nport=" + std::to_string(current_port) + "\n");

    const auto request_path = current_dir / "connect-request.txt";
    while (!stop_requested)
    {
        std::error_code error;
        if (std::filesystem::exists(request_path, error))
        {
            ProcessConnectRequest(request_path);
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    WriteTextFile(current_dir / "loader-status.txt", "loaded=1\nwatcher=stopped\n");
    Log::Write("menu command watcher stopped");
}

void CommandWatcher::ProcessConnectRequest(const std::filesystem::path& request_path)
{
    std::ifstream input(request_path);
    std::stringstream buffer;
    buffer << input.rdbuf();
    const auto text = buffer.str();
    input.close();

    std::error_code remove_error;
    std::filesystem::remove(request_path, remove_error);

    std::string current_host;
    uint16_t current_port = 27016;
    std::filesystem::path current_dir;
    {
        std::scoped_lock lock(mutex);
        current_host = server_host;
        current_port = server_port;
        current_dir = directory;
    }

    const auto reason = ReadKey(text, "reason", "main-menu");
    const auto context = ReadKey(text, "context", "");

    Log::Write("menu connect command received reason=" + reason + " context=" + context);
    WriteTextFile(current_dir / "last-command.txt", text);

    CyrodiilMP_ConnectOptions options{};
    options.host = current_host.c_str();
    options.port = current_port;
    options.player_name = "OblivionMenu";
    options.reason = reason.c_str();
    options.log_path = nullptr;
    NetworkClient::Instance().Connect(options);

    std::this_thread::sleep_for(std::chrono::milliseconds(3500));
    CyrodiilMP_ClientStatus status{};
    NetworkClient::Instance().GetStatus(status);
    WriteTextFile(current_dir / "last-status.txt",
        std::string("connected=") + (status.connected ? "1" : "0") +
        "\nerror=" + std::to_string(status.last_error) +
        "\nmessage=" + status.last_message + "\n");
}

void CommandWatcher::WriteTextFile(const std::filesystem::path& path, const std::string& text) const
{
    std::filesystem::create_directories(path.parent_path());
    std::ofstream output(path, std::ios::trunc);
    output << text;
}

}
