#include "NetworkClient.hpp"

#include "Log.hpp"

#include <array>
#include <sstream>

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>

namespace CyrodiilMP::GameClient {

namespace {

std::string SafeText(const char* value, const char* fallback)
{
    if (value == nullptr || value[0] == '\0')
    {
        return fallback;
    }

    std::string text(value);
    for (auto& ch : text)
    {
        if (ch == ' ' || ch == '\r' || ch == '\n' || ch == '"')
        {
            ch = '_';
        }
    }
    return text;
}

}

NetworkClient::~NetworkClient()
{
    Disconnect();
}

NetworkClient& NetworkClient::Instance()
{
    static NetworkClient instance;
    return instance;
}

int NetworkClient::Connect(const CyrodiilMP_ConnectOptions& options)
{
    Disconnect();

    const auto host = SafeText(options.host, "127.0.0.1");
    const auto player_name = SafeText(options.player_name, "OblivionNative");
    const auto reason = SafeText(options.reason, "native-connect");
    const auto port = options.port == 0 ? static_cast<uint16_t>(27016) : options.port;

    stop_requested = false;
    SetStatus(false, 0, "connecting");
    Log::Write("connect requested host=" + host + " port=" + std::to_string(port));

    worker = std::thread(&NetworkClient::Run, this, host, port, player_name, reason);
    return 0;
}

void NetworkClient::Disconnect()
{
    stop_requested = true;
    if (worker.joinable())
    {
        worker.join();
    }
    connected = false;
}

bool NetworkClient::IsConnected() const
{
    return connected.load();
}

void NetworkClient::GetStatus(CyrodiilMP_ClientStatus& status) const
{
    std::scoped_lock lock(mutex);
    status.connected = connected.load() ? 1 : 0;
    status.last_error = last_error;
    strncpy_s(status.last_message, last_message.c_str(), _TRUNCATE);
}

void NetworkClient::SetStatus(bool is_connected, int error, const std::string& message)
{
    std::scoped_lock lock(mutex);
    connected = is_connected;
    last_error = error;
    last_message = message;
}

void NetworkClient::Run(std::string host, uint16_t port, std::string player_name, std::string reason)
{
    WSADATA wsa{};
    auto startup_result = WSAStartup(MAKEWORD(2, 2), &wsa);
    if (startup_result != 0)
    {
        SetStatus(false, startup_result, "WSAStartup failed");
        Log::Write("WSAStartup failed error=" + std::to_string(startup_result));
        return;
    }

    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock == INVALID_SOCKET)
    {
        const auto error = WSAGetLastError();
        WSACleanup();
        SetStatus(false, error, "socket failed");
        Log::Write("socket failed error=" + std::to_string(error));
        return;
    }

    timeval timeout{};
    timeout.tv_sec = 3;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeout), sizeof(timeout));

    sockaddr_in endpoint{};
    endpoint.sin_family = AF_INET;
    endpoint.sin_port = htons(port);
    if (inet_pton(AF_INET, host.c_str(), &endpoint.sin_addr) != 1)
    {
        closesocket(sock);
        WSACleanup();
        SetStatus(false, WSAEINVAL, "invalid IPv4 host");
        Log::Write("invalid IPv4 host: " + host);
        return;
    }

    std::ostringstream payload;
    payload << "native-hello name=" << player_name
            << " reason=" << reason
            << " protocol=0";
    const auto text = payload.str();

    const auto sent = sendto(
        sock,
        text.data(),
        static_cast<int>(text.size()),
        0,
        reinterpret_cast<sockaddr*>(&endpoint),
        sizeof(endpoint));

    if (sent == SOCKET_ERROR)
    {
        const auto error = WSAGetLastError();
        closesocket(sock);
        WSACleanup();
        SetStatus(false, error, "sendto failed");
        Log::Write("sendto failed error=" + std::to_string(error));
        return;
    }

    Log::Write("sent " + text);

    std::array<char, 1024> buffer{};
    sockaddr_in from{};
    int from_len = sizeof(from);
    const auto received = recvfrom(
        sock,
        buffer.data(),
        static_cast<int>(buffer.size() - 1),
        0,
        reinterpret_cast<sockaddr*>(&from),
        &from_len);

    if (received > 0)
    {
        buffer[static_cast<size_t>(received)] = '\0';
        std::string response(buffer.data());
        SetStatus(true, 0, response);
        Log::Write("received " + response);
    }
    else
    {
        const auto error = WSAGetLastError();
        SetStatus(false, error, "no native UDP response");
        Log::Write("recvfrom failed or timed out error=" + std::to_string(error));
    }

    closesocket(sock);
    WSACleanup();
}

}
