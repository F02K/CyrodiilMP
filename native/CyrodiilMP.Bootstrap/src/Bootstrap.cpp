#include "Bootstrap.hpp"

#include "Log.hpp"
#include "Settings.hpp"
#include "UiRuntime.hpp"
#include "UEBridge.hpp"

#include <cstdint>
#include <filesystem>
#include <string>

namespace CyrodiilMP::Bootstrap {

namespace {

using InitializeFn = int (*)(const char*);
using StartWatcherFn = int (*)(const char*, const char*, uint16_t);
using StopWatcherFn = void (*)();

HANDLE g_worker_thread = nullptr;
HMODULE g_game_client_module = nullptr;
HMODULE g_self_module = nullptr;

std::filesystem::path GetModulePath(HMODULE module)
{
    wchar_t buffer[MAX_PATH]{};
    GetModuleFileNameW(module, buffer, MAX_PATH);
    return std::filesystem::path(buffer);
}

std::filesystem::path GetGameExePath()
{
    wchar_t buffer[MAX_PATH]{};
    GetModuleFileNameW(nullptr, buffer, MAX_PATH);
    return std::filesystem::path(buffer);
}

std::filesystem::path GetWin64Directory()
{
    return GetGameExePath().parent_path();
}

DWORD WINAPI WorkerThread(LPVOID)
{
    const auto win64_dir = GetWin64Directory();
    const auto root_dir = win64_dir / "CyrodiilMP";
    const auto bootstrap_dir = root_dir / "Bootstrap";
    const auto game_client_dir = root_dir / "GameClient";
    const auto ui_dir = root_dir / "UI" / "cyrodiilmp";
    const auto bootstrap_log = bootstrap_dir / "Bootstrap.log";
    const auto game_client_log = game_client_dir / "GameClient.log";
    const auto game_client_dll = game_client_dir / "CyrodiilMP.GameClient.dll";

    Log::Initialize(bootstrap_log);
    Log::Write("CyrodiilMP.Bootstrap loaded");
    Log::Write("bootstrap_dll=" + GetModulePath(g_self_module).string());
    Log::Write("game_exe=" + GetGameExePath().string());
    Log::Write("win64_dir=" + win64_dir.string());

    const auto settings_path = bootstrap_dir / "settings.ini";
    const auto settings = LoadSettings(settings_path);
    Log::Write("settings=" + settings_path.string());

    UEBridge::Initialize(GetGameExePath(), UEBridgeSettings{
        settings.enable_ue_pattern_scan,
        bootstrap_dir
    });
    UEBridge::CaptureStartupSnapshot();

    auto* loaded = LoadLibraryW(game_client_dll.wstring().c_str());
    if (loaded == nullptr)
    {
        Log::Write("LoadLibraryW GameClient failed path=" + game_client_dll.string() + " error=" + std::to_string(GetLastError()));
        return 1;
    }

    g_game_client_module = loaded;
    auto* initialize = reinterpret_cast<InitializeFn>(GetProcAddress(loaded, "CyrodiilMP_Initialize"));
    auto* start_watcher = reinterpret_cast<StartWatcherFn>(GetProcAddress(loaded, "CyrodiilMP_StartMenuCommandWatcher"));

    if (initialize == nullptr || start_watcher == nullptr)
    {
        Log::Write("GameClient exports missing");
        return 2;
    }

    const auto game_client_log_text = game_client_log.string();
    const auto game_client_dir_text = game_client_dir.string();
    initialize(game_client_log_text.c_str());
    start_watcher(game_client_dir_text.c_str(), "127.0.0.1", 27016);

    Log::Write("GameClient initialized from standalone bootstrap");

    if (settings.enable_nirnlab_ui)
    {
        UiRuntime::Instance().Initialize(UiRuntimeSettings{
            root_dir,
            game_client_dir,
            ui_dir,
            settings.show_main_menu_button
        });
    }
    else
    {
        Log::Write("UiRuntime disabled by settings");
    }

    return 0;
}

}

void Start(HMODULE self_module)
{
    g_self_module = self_module;
    g_worker_thread = CreateThread(nullptr, 0, WorkerThread, nullptr, 0, nullptr);
}

void Stop()
{
    UiRuntime::Instance().Shutdown();

    if (g_game_client_module != nullptr)
    {
        auto* stop_watcher = reinterpret_cast<StopWatcherFn>(GetProcAddress(g_game_client_module, "CyrodiilMP_StopMenuCommandWatcher"));
        if (stop_watcher != nullptr)
        {
            stop_watcher();
        }
    }

    if (g_worker_thread != nullptr)
    {
        CloseHandle(g_worker_thread);
        g_worker_thread = nullptr;
    }
}

}
