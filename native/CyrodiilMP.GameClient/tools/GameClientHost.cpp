#include <CyrodiilMP/GameClientApi.h>

#include <chrono>
#include <iostream>
#include <string>
#include <thread>

namespace {

std::string GetOption(int argc, char** argv, const std::string& name, const std::string& fallback)
{
    for (int i = 1; i < argc - 1; ++i)
    {
        if (argv[i] == name)
        {
            return argv[i + 1];
        }
    }

    return fallback;
}

}

int main(int argc, char** argv)
{
    const auto host = GetOption(argc, argv, "--host", "127.0.0.1");
    const auto port_text = GetOption(argc, argv, "--port", "27016");
    const auto name = GetOption(argc, argv, "--name", "NativeHost");
    const auto reason = GetOption(argc, argv, "--reason", "manual-native-host");
    const auto log_path = GetOption(argc, argv, "--log", "research/net-smoke/native-gameclient.log");

    CyrodiilMP_ConnectOptions options{};
    options.host = host.c_str();
    options.port = static_cast<uint16_t>(std::stoi(port_text));
    options.player_name = name.c_str();
    options.reason = reason.c_str();
    options.log_path = log_path.c_str();

    const auto connect_result = CyrodiilMP_Connect(&options);
    if (connect_result != 0)
    {
        std::cerr << "CyrodiilMP_Connect failed: " << connect_result << "\n";
        return 1;
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(1300));

    CyrodiilMP_ClientStatus status{};
    CyrodiilMP_GetStatus(&status);

    std::cout << "connected=" << status.connected
              << " error=" << status.last_error
              << " message=\"" << status.last_message << "\"\n";

    CyrodiilMP_Disconnect();
    return status.connected ? 0 : 1;
}
