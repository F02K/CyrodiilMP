#include "UiRuntime.hpp"

#include "Log.hpp"

#include <NirnLabUIPlatformAPI/Host.h>
#include <NirnLabUIPlatformAPI/IBrowser.h>
#include <NirnLabUIPlatformAPI/JSTypes.h>
#include <NirnLabUIPlatformAPI/Settings.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <system_error>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>

namespace NL::UI {

class IUIPlatformAPI
{
public:
    using BrowserRefHandle = std::uint32_t;
    static constexpr BrowserRefHandle InvalidBrowserRefHandle = 0;
    using OnShutdownFunc_t = void (*)();

    virtual ~IUIPlatformAPI() = default;
    virtual BrowserRefHandle __cdecl AddOrGetBrowser(const char* browser_name,
                                                     NL::JS::JSFuncInfo* const* callbacks,
                                                     std::uint32_t callback_count,
                                                     const char* start_url,
                                                     NL::CEF::IBrowser*& out_browser) = 0;
    virtual void __cdecl ReleaseBrowserHandle(BrowserRefHandle handle) = 0;
    virtual BrowserRefHandle __cdecl AddOrGetBrowser(const char* browser_name,
                                                     NL::JS::JSFuncInfo* const* callbacks,
                                                     std::uint32_t callback_count,
                                                     const char* start_url,
                                                     NL::UI::BrowserSettings* settings,
                                                     NL::CEF::IBrowser*& out_browser) = 0;
    virtual void RegisterOnShutdown(OnShutdownFunc_t callback) = 0;
};

}

namespace CyrodiilMP::Bootstrap {

namespace {

using CreateOrGetUIPlatformAPI = bool (*)(NL::UI::IUIPlatformAPI**, NL::UI::Settings*);
using GetUIPlatformHostInfo = NL::UI::HostInfo (*)();

HMODULE g_ui_module = nullptr;
NL::UI::IUIPlatformAPI* g_api = nullptr;
NL::CEF::IBrowser* g_button_browser = nullptr;
NL::CEF::IBrowser* g_panel_browser = nullptr;
NL::UI::IUIPlatformAPI::BrowserRefHandle g_button_handle = NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle;
NL::UI::IUIPlatformAPI::BrowserRefHandle g_panel_handle = NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle;
UiRuntimeSettings g_settings;

std::string Narrow(const std::filesystem::path& path)
{
    return path.string();
}

std::string UrlEncodePathChar(char ch)
{
    const auto value = static_cast<unsigned char>(ch);
    if ((value >= 'A' && value <= 'Z') ||
        (value >= 'a' && value <= 'z') ||
        (value >= '0' && value <= '9') ||
        ch == '/' || ch == ':' || ch == '-' || ch == '_' || ch == '.' || ch == '~')
    {
        return std::string(1, ch);
    }

    std::ostringstream stream;
    stream << '%' << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(value);
    return stream.str();
}

std::string ToFileUrl(std::filesystem::path path)
{
    path = std::filesystem::absolute(std::move(path));
    auto text = Narrow(path);
    std::replace(text.begin(), text.end(), '\\', '/');

    std::string encoded;
    encoded.reserve(text.size() + 8);
    for (char ch : text)
    {
        encoded += UrlEncodePathChar(ch);
    }

    if (encoded.rfind("/", 0) == 0)
    {
        return "file://" + encoded;
    }

    return "file:///" + encoded;
}

void WriteConnectRequest(std::string_view reason, std::string_view context)
{
    const auto request_path = g_settings.game_client_directory / "connect-request.txt";
    std::error_code ignored;
    std::filesystem::create_directories(request_path.parent_path(), ignored);

    std::ofstream output(request_path, std::ios::binary | std::ios::trunc);
    output << "reason=" << reason << "\n";
    output << "context=" << context << "\n";
    Log::Write("UiRuntime wrote connect request " + request_path.string());
}

void InvokeCallback(const char** args, int arg_count);

bool EnsurePanel()
{
    if (g_api == nullptr)
    {
        return false;
    }

    if (g_panel_browser != nullptr)
    {
        return true;
    }

    const auto panel_url = ToFileUrl(g_settings.ui_directory / "index.html");
    NL::UI::BrowserSettings browser_settings{};
    browser_settings.frameRate = 60;

    static NL::JS::JSFuncInfo invoke_callback{
        "CyrodiilMP",
        "invoke",
        { InvokeCallback, false, false }
    };

    NL::JS::JSFuncInfo* callbacks[] = { &invoke_callback };
    g_panel_handle = g_api->AddOrGetBrowser(
        "cyrodiilmp.main-menu",
        callbacks,
        1,
        panel_url.c_str(),
        &browser_settings,
        g_panel_browser);

    if (g_panel_handle == NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle || g_panel_browser == nullptr)
    {
        Log::Write("UiRuntime could not create cyrodiilmp.main-menu browser");
        return false;
    }

    g_panel_browser->SetBrowserVisible(false);
    g_panel_browser->SetBrowserFocused(false);
    Log::Write("UiRuntime created panel browser url=" + panel_url);
    return true;
}

void ShowPanel()
{
    if (!EnsurePanel())
    {
        return;
    }

    g_panel_browser->SetBrowserVisible(true);
    g_panel_browser->SetBrowserFocused(true);
    g_panel_browser->ExecEventFunction("statusChanged", "{\"message\":\"Ready\"}");
    Log::Write("UiRuntime showed cyrodiilmp.main-menu");
}

void HidePanel()
{
    if (g_panel_browser == nullptr)
    {
        return;
    }

    g_panel_browser->SetBrowserFocused(false);
    g_panel_browser->SetBrowserVisible(false);
    Log::Write("UiRuntime hid cyrodiilmp.main-menu");
}

void InvokeCallback(const char** args, int arg_count)
{
    const std::string command = (arg_count > 0 && args != nullptr && args[0] != nullptr) ? args[0] : "";
    const std::string payload = (arg_count > 1 && args != nullptr && args[1] != nullptr) ? args[1] : "";
    Log::Write("UiRuntime JS command=" + command + " payload=" + payload);

    if (command == "cyrodiilmp.openMainMenu")
    {
        ShowPanel();
    }
    else if (command == "cyrodiilmp.close")
    {
        HidePanel();
    }
    else if (command == "cyrodiilmp.connect")
    {
        WriteConnectRequest("nirnlab-ui", payload);
        if (g_panel_browser != nullptr)
        {
            g_panel_browser->ExecEventFunction("statusChanged", "{\"message\":\"Connect request sent\"}");
        }
    }
    else if (command == "cyrodiilmp.disconnect")
    {
        Log::Write("UiRuntime disconnect requested; direct GameClient disconnect wiring is pending");
        if (g_panel_browser != nullptr)
        {
            g_panel_browser->ExecEventFunction("statusChanged", "{\"message\":\"Disconnect requested\"}");
        }
    }
}

std::filesystem::path FindUiPlatformDll(const std::filesystem::path& root_directory)
{
    const std::filesystem::path candidates[] = {
        root_directory / "NirnLabUIPlatformOR" / "NirnLabUIPlatformOR.dll",
        root_directory / "Standalone" / "NirnLabUIPlatformOR.dll"
    };

    for (const auto& candidate : candidates)
    {
        if (std::filesystem::exists(candidate))
        {
            return candidate;
        }
    }

    return candidates[0];
}

std::string FormatWin32Error(DWORD error)
{
    return std::system_category().message(static_cast<int>(error));
}

HMODULE LoadUiPlatformDll(const std::filesystem::path& dll_path, DWORD& error)
{
    error = ERROR_SUCCESS;
    if (!std::filesystem::exists(dll_path))
    {
        error = ERROR_FILE_NOT_FOUND;
        return nullptr;
    }

    auto* module = LoadLibraryExW(
        dll_path.wstring().c_str(),
        nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (module != nullptr)
    {
        return module;
    }

    error = GetLastError();
    module = LoadLibraryExW(dll_path.wstring().c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (module != nullptr)
    {
        error = ERROR_SUCCESS;
        return module;
    }

    error = GetLastError();
    return nullptr;
}

}

UiRuntime& UiRuntime::Instance()
{
    static UiRuntime instance;
    return instance;
}

bool UiRuntime::Initialize(UiRuntimeSettings settings)
{
    g_settings = std::move(settings);

    const auto dll_path = FindUiPlatformDll(g_settings.root_directory);
    DWORD load_error = ERROR_SUCCESS;
    g_ui_module = LoadUiPlatformDll(dll_path, load_error);
    if (g_ui_module == nullptr)
    {
        const auto exists = std::filesystem::exists(dll_path) ? "true" : "false";
        Log::Write(
            "UiRuntime disabled: failed to load NirnLabUIPlatformOR path=" + dll_path.string() +
            " exists=" + exists +
            " error=" + std::to_string(load_error) +
            " message=" + FormatWin32Error(load_error));
        return false;
    }

    auto* get_host_info = reinterpret_cast<GetUIPlatformHostInfo>(GetProcAddress(g_ui_module, "GetUIPlatformHostInfo"));
    if (get_host_info != nullptr)
    {
        const auto host = get_host_info();
        Log::Write(
            std::string("UiRuntime host runtime=") + (host.runtimeName == nullptr ? "" : host.runtimeName) +
            " game=" + (host.gameName == nullptr ? "" : host.gameName) +
            " integration=" + (host.integrationName == nullptr ? "" : host.integrationName));
    }

    auto* create_api = reinterpret_cast<CreateOrGetUIPlatformAPI>(GetProcAddress(g_ui_module, "CreateOrGetUIPlatformAPI"));
    if (create_api == nullptr)
    {
        Log::Write("UiRuntime disabled: CreateOrGetUIPlatformAPI export missing");
        return false;
    }

    NL::UI::Settings ui_settings{};
    ui_settings.nativeMenuLangSwitching = false;
    if (!create_api(&g_api, &ui_settings) || g_api == nullptr)
    {
        Log::Write("UiRuntime disabled: CreateOrGetUIPlatformAPI failed");
        return false;
    }

    Log::Write("UiRuntime initialized with NirnLabUIPlatformOR");
    if (g_settings.show_main_menu_button)
    {
        ShowMainMenuButton();
    }

    return true;
}

void UiRuntime::ShowMainMenuButton()
{
    if (g_api == nullptr)
    {
        return;
    }

    const auto button_url = ToFileUrl(g_settings.ui_directory / "main-menu-button.html");
    NL::UI::BrowserSettings browser_settings{};
    browser_settings.frameRate = 30;

    static NL::JS::JSFuncInfo invoke_callback{
        "CyrodiilMP",
        "invoke",
        { InvokeCallback, false, false }
    };

    NL::JS::JSFuncInfo* callbacks[] = { &invoke_callback };
    g_button_handle = g_api->AddOrGetBrowser(
        "cyrodiilmp.main-menu-button",
        callbacks,
        1,
        button_url.c_str(),
        &browser_settings,
        g_button_browser);

    if (g_button_handle == NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle || g_button_browser == nullptr)
    {
        Log::Write("UiRuntime could not create cyrodiilmp.main-menu-button browser");
        return;
    }

    g_button_browser->SetBrowserVisible(true);
    g_button_browser->SetBrowserFocused(false);
    Log::Write("UiRuntime showed main menu button url=" + button_url);
}

void UiRuntime::Shutdown()
{
    if (g_api != nullptr)
    {
        if (g_button_handle != NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle)
        {
            g_api->ReleaseBrowserHandle(g_button_handle);
            g_button_handle = NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle;
            g_button_browser = nullptr;
        }

        if (g_panel_handle != NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle)
        {
            g_api->ReleaseBrowserHandle(g_panel_handle);
            g_panel_handle = NL::UI::IUIPlatformAPI::InvalidBrowserRefHandle;
            g_panel_browser = nullptr;
        }
    }

    g_api = nullptr;
    if (g_ui_module != nullptr)
    {
        FreeLibrary(g_ui_module);
        g_ui_module = nullptr;
    }
}

}
