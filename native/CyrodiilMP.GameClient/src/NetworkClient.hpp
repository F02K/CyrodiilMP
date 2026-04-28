#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>

#include <CyrodiilMP/GameClientApi.h>

namespace CyrodiilMP::GameClient {

class NetworkClient
{
public:
    static NetworkClient& Instance();

    int Connect(const CyrodiilMP_ConnectOptions& options);
    void Disconnect();
    bool IsConnected() const;
    void GetStatus(CyrodiilMP_ClientStatus& status) const;

private:
    NetworkClient() = default;
    ~NetworkClient();

    void Run(std::string host, uint16_t port, std::string player_name, std::string reason);
    void SetStatus(bool connected, int error, const std::string& message);

    mutable std::mutex mutex;
    std::thread worker;
    std::atomic<bool> stop_requested{false};
    std::atomic<bool> connected{false};
    int last_error = 0;
    std::string last_message = "idle";
};

}
