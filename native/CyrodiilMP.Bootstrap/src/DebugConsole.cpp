#include "DebugConsole.hpp"

#include "Log.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace CyrodiilMP::Bootstrap::DebugConsole {

namespace {

bool g_allocated_console = false;

}

bool Initialize(bool enabled)
{
    if (!enabled)
    {
        Log::SetConsoleEcho(false);
        return false;
    }

    if (GetConsoleWindow() == nullptr)
    {
        g_allocated_console = AllocConsole() != 0;
    }

    if (GetConsoleWindow() == nullptr)
    {
        Log::SetConsoleEcho(false);
        return false;
    }

    SetConsoleTitleW(L"CyrodiilMP Bootstrap Debug Console");
    SetConsoleOutputCP(CP_UTF8);
    Log::SetConsoleEcho(true);
    Log::Write("Debug console enabled");
    return true;
}

void Shutdown()
{
    Log::Write("Debug console shutdown");
    Log::SetConsoleEcho(false);

    if (g_allocated_console)
    {
        FreeConsole();
        g_allocated_console = false;
    }
}

}
