#include "Bootstrap.hpp"

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(module);
        CyrodiilMP::Bootstrap::Start(module);
    }
    else if (reason == DLL_PROCESS_DETACH)
    {
        CyrodiilMP::Bootstrap::Stop();
    }

    return TRUE;
}
