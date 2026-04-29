#include "DebugConsole.hpp"

#include "Log.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdio>

namespace CyrodiilMP::Bootstrap::DebugConsole {

namespace {

bool g_allocated_console = false;
bool g_initialized = false;

void RedirectStandardStreams()
{
    const auto input = CreateFileW(L"CONIN$", GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (input != INVALID_HANDLE_VALUE)
    {
        SetStdHandle(STD_INPUT_HANDLE, input);
    }

    const auto output = CreateFileW(L"CONOUT$", GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (output != INVALID_HANDLE_VALUE)
    {
        SetStdHandle(STD_OUTPUT_HANDLE, output);
        SetStdHandle(STD_ERROR_HANDLE, output);
    }

    FILE* stream = nullptr;
    (void)freopen_s(&stream, "CONIN$", "r", stdin);
    (void)freopen_s(&stream, "CONOUT$", "w", stdout);
    (void)freopen_s(&stream, "CONOUT$", "w", stderr);
}

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
        if (AttachConsole(ATTACH_PARENT_PROCESS) == 0)
        {
            g_allocated_console = AllocConsole() != 0;
        }
    }

    if (GetConsoleWindow() == nullptr)
    {
        Log::SetConsoleEcho(false);
        return false;
    }

    RedirectStandardStreams();
    SetConsoleTitleW(L"CyrodiilMP Bootstrap Debug Console");
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
    ShowWindow(GetConsoleWindow(), SW_SHOW);
    Log::SetConsoleEcho(true);
    g_initialized = true;
    Log::Write("Debug console enabled");
    return true;
}

void Shutdown()
{
    if (g_initialized)
    {
        Log::Write("Debug console shutdown");
        Log::SetConsoleEcho(false);
        g_initialized = false;
    }

    if (g_allocated_console)
    {
        FreeConsole();
        g_allocated_console = false;
    }
}

}
