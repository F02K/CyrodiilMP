#pragma once

#include <stdint.h>

#ifdef CYRODIILMP_GAMECLIENT_EXPORTS
#define CYRODIILMP_API __declspec(dllexport)
#else
#define CYRODIILMP_API __declspec(dllimport)
#endif

extern "C" {

struct CyrodiilMP_ConnectOptions
{
    const char* host;
    uint16_t port;
    const char* player_name;
    const char* reason;
    const char* log_path;
};

struct CyrodiilMP_ClientStatus
{
    int connected;
    int last_error;
    char last_message[512];
};

CYRODIILMP_API int CyrodiilMP_Initialize(const char* log_path);
CYRODIILMP_API int CyrodiilMP_Connect(const CyrodiilMP_ConnectOptions* options);
CYRODIILMP_API void CyrodiilMP_Disconnect();
CYRODIILMP_API int CyrodiilMP_IsConnected();
CYRODIILMP_API void CyrodiilMP_GetStatus(CyrodiilMP_ClientStatus* status);
CYRODIILMP_API const char* CyrodiilMP_GetVersion();
CYRODIILMP_API const char* CyrodiilMP_GetMainMenuButtonLabel();
CYRODIILMP_API int CyrodiilMP_StartMenuCommandWatcher(const char* command_dir, const char* host, uint16_t port);
CYRODIILMP_API void CyrodiilMP_StopMenuCommandWatcher();
CYRODIILMP_API int luaopen_CyrodiilMP_GameClient(void* lua_state);

}
