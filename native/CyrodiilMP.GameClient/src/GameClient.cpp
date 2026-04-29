#define CYRODIILMP_GAMECLIENT_EXPORTS
#include <CyrodiilMP/GameClientApi.h>

#include "CommandWatcher.hpp"
#include "Log.hpp"
#include "NetworkClient.hpp"

#include <filesystem>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace {

std::filesystem::path GetThisDllDirectory()
{
    HMODULE module = nullptr;
    const auto flags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
    if (!GetModuleHandleExA(flags, reinterpret_cast<LPCSTR>(&GetThisDllDirectory), &module) || module == nullptr)
    {
        return std::filesystem::path("CyrodiilMP") / "GameClient";
    }

    char buffer[MAX_PATH]{};
    if (GetModuleFileNameA(module, buffer, MAX_PATH) == 0)
    {
        return std::filesystem::path("CyrodiilMP") / "GameClient";
    }

    return std::filesystem::path(buffer).parent_path();
}

}

extern "C" {

int CyrodiilMP_Initialize(const char* log_path)
{
    CyrodiilMP::GameClient::Log::Initialize(log_path == nullptr ? "" : log_path);
    CyrodiilMP::GameClient::Log::Write("CyrodiilMP.GameClient initialized");
    return 0;
}

int CyrodiilMP_Connect(const CyrodiilMP_ConnectOptions* options)
{
    if (options == nullptr)
    {
        return -1;
    }

    CyrodiilMP::GameClient::Log::Initialize(options->log_path == nullptr ? "" : options->log_path);
    return CyrodiilMP::GameClient::NetworkClient::Instance().Connect(*options);
}

void CyrodiilMP_Disconnect()
{
    CyrodiilMP::GameClient::NetworkClient::Instance().Disconnect();
}

int CyrodiilMP_IsConnected()
{
    return CyrodiilMP::GameClient::NetworkClient::Instance().IsConnected() ? 1 : 0;
}

void CyrodiilMP_GetStatus(CyrodiilMP_ClientStatus* status)
{
    if (status == nullptr)
    {
        return;
    }

    CyrodiilMP::GameClient::NetworkClient::Instance().GetStatus(*status);
}

const char* CyrodiilMP_GetVersion()
{
    return "0.1.0";
}

const char* CyrodiilMP_GetMainMenuButtonLabel()
{
    return "MULTIPLAYER";
}

int CyrodiilMP_StartMenuCommandWatcher(const char* command_dir, const char* host, uint16_t port)
{
    return CyrodiilMP::GameClient::CommandWatcher::Instance().Start(
        command_dir == nullptr ? "" : command_dir,
        host == nullptr ? "127.0.0.1" : host,
        port == 0 ? static_cast<uint16_t>(27016) : port);
}

void CyrodiilMP_StopMenuCommandWatcher()
{
    CyrodiilMP::GameClient::CommandWatcher::Instance().Stop();
}

int luaopen_CyrodiilMP_GameClient(void*)
{
    const auto command_dir = GetThisDllDirectory();
    const auto log_path = command_dir / "GameClient.log";
    const auto command_dir_text = command_dir.string();
    const auto log_path_text = log_path.string();

    CyrodiilMP_Initialize(log_path_text.c_str());
    return CyrodiilMP_StartMenuCommandWatcher(command_dir_text.c_str(), "127.0.0.1", 27016);
}

}
