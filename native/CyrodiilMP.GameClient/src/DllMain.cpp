#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "CommandWatcher.hpp"
#include "NetworkClient.hpp"

BOOL APIENTRY DllMain(HMODULE, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_DETACH)
    {
        CyrodiilMP::GameClient::CommandWatcher::Instance().Stop();
        CyrodiilMP::GameClient::NetworkClient::Instance().Disconnect();
    }

    return TRUE;
}
