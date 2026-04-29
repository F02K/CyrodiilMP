#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <filesystem>
#include <string>

namespace {

HMODULE g_real_version = nullptr;
HMODULE g_self_module = nullptr;
HMODULE g_bootstrap_module = nullptr;
INIT_ONCE g_real_version_once = INIT_ONCE_STATIC_INIT;

BOOL CALLBACK LoadRealVersionDll(PINIT_ONCE, PVOID, PVOID*)
{
    wchar_t system_dir[MAX_PATH]{};
    const auto size = GetSystemDirectoryW(system_dir, MAX_PATH);
    if (size == 0 || size >= MAX_PATH)
    {
        return FALSE;
    }

    const auto path = std::filesystem::path(system_dir) / L"version.dll";
    g_real_version = LoadLibraryW(path.wstring().c_str());
    return g_real_version != nullptr;
}

FARPROC GetRealProc(const char* name)
{
    InitOnceExecuteOnce(&g_real_version_once, LoadRealVersionDll, nullptr, nullptr);
    if (g_real_version == nullptr)
    {
        return nullptr;
    }

    return GetProcAddress(g_real_version, name);
}

std::filesystem::path GetModuleDirectory(HMODULE module)
{
    wchar_t path[MAX_PATH]{};
    GetModuleFileNameW(module, path, MAX_PATH);
    return std::filesystem::path(path).parent_path();
}

void WriteDebugLine(const std::wstring& message)
{
    OutputDebugStringW((L"[CyrodiilMP.AutoLoader] " + message + L"\n").c_str());
}

DWORD WINAPI LoadBootstrapThread(LPVOID)
{
    const auto bootstrap_path = GetModuleDirectory(g_self_module) / L"CyrodiilMP" / L"Standalone" / L"CyrodiilMP.Bootstrap.dll";
    g_bootstrap_module = LoadLibraryW(bootstrap_path.wstring().c_str());
    if (g_bootstrap_module == nullptr)
    {
        WriteDebugLine(L"failed to load " + bootstrap_path.wstring() + L" error=" + std::to_wstring(GetLastError()));
        return 1;
    }

    WriteDebugLine(L"loaded " + bootstrap_path.wstring());
    return 0;
}

template <typename Fn, typename Fallback, typename... Args>
auto CallVersionApi(const char* name, Fallback fallback, Args... args)
{
    auto* proc = reinterpret_cast<Fn>(GetRealProc(name));
    if (proc == nullptr)
    {
        return fallback;
    }

    return proc(args...);
}

}

extern "C" BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_self_module = instance;
        DisableThreadLibraryCalls(instance);
        HANDLE thread = CreateThread(nullptr, 0, LoadBootstrapThread, nullptr, 0, nullptr);
        if (thread != nullptr)
        {
            CloseHandle(thread);
        }
    }

    return TRUE;
}

extern "C" BOOL WINAPI ProxyGetFileVersionInfoA(LPCSTR file_name, DWORD handle, DWORD length, LPVOID data)
{
    using Fn = BOOL (WINAPI*)(LPCSTR, DWORD, DWORD, LPVOID);
    return CallVersionApi<Fn>("GetFileVersionInfoA", FALSE, file_name, handle, length, data);
}

extern "C" BOOL WINAPI ProxyGetFileVersionInfoW(LPCWSTR file_name, DWORD handle, DWORD length, LPVOID data)
{
    using Fn = BOOL (WINAPI*)(LPCWSTR, DWORD, DWORD, LPVOID);
    return CallVersionApi<Fn>("GetFileVersionInfoW", FALSE, file_name, handle, length, data);
}

extern "C" BOOL WINAPI ProxyGetFileVersionInfoByHandle(DWORD handle, DWORD offset, DWORD length, LPVOID data)
{
    using Fn = BOOL (WINAPI*)(DWORD, DWORD, DWORD, LPVOID);
    return CallVersionApi<Fn>("GetFileVersionInfoByHandle", FALSE, handle, offset, length, data);
}

extern "C" BOOL WINAPI ProxyGetFileVersionInfoExA(DWORD flags, LPCSTR file_name, DWORD handle, DWORD length, LPVOID data)
{
    using Fn = BOOL (WINAPI*)(DWORD, LPCSTR, DWORD, DWORD, LPVOID);
    return CallVersionApi<Fn>("GetFileVersionInfoExA", FALSE, flags, file_name, handle, length, data);
}

extern "C" BOOL WINAPI ProxyGetFileVersionInfoExW(DWORD flags, LPCWSTR file_name, DWORD handle, DWORD length, LPVOID data)
{
    using Fn = BOOL (WINAPI*)(DWORD, LPCWSTR, DWORD, DWORD, LPVOID);
    return CallVersionApi<Fn>("GetFileVersionInfoExW", FALSE, flags, file_name, handle, length, data);
}

extern "C" DWORD WINAPI ProxyGetFileVersionInfoSizeA(LPCSTR file_name, LPDWORD handle)
{
    using Fn = DWORD (WINAPI*)(LPCSTR, LPDWORD);
    return CallVersionApi<Fn>("GetFileVersionInfoSizeA", 0UL, file_name, handle);
}

extern "C" DWORD WINAPI ProxyGetFileVersionInfoSizeW(LPCWSTR file_name, LPDWORD handle)
{
    using Fn = DWORD (WINAPI*)(LPCWSTR, LPDWORD);
    return CallVersionApi<Fn>("GetFileVersionInfoSizeW", 0UL, file_name, handle);
}

extern "C" DWORD WINAPI ProxyGetFileVersionInfoSizeExA(DWORD flags, LPCSTR file_name, LPDWORD handle)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCSTR, LPDWORD);
    return CallVersionApi<Fn>("GetFileVersionInfoSizeExA", 0UL, flags, file_name, handle);
}

extern "C" DWORD WINAPI ProxyGetFileVersionInfoSizeExW(DWORD flags, LPCWSTR file_name, LPDWORD handle)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCWSTR, LPDWORD);
    return CallVersionApi<Fn>("GetFileVersionInfoSizeExW", 0UL, flags, file_name, handle);
}

extern "C" DWORD WINAPI ProxyVerFindFileA(DWORD flags, LPCSTR file_name, LPCSTR win_dir, LPCSTR app_dir, LPSTR cur_dir, PUINT cur_dir_len, LPSTR dest_dir, PUINT dest_dir_len)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCSTR, LPCSTR, LPCSTR, LPSTR, PUINT, LPSTR, PUINT);
    return CallVersionApi<Fn>("VerFindFileA", 0UL, flags, file_name, win_dir, app_dir, cur_dir, cur_dir_len, dest_dir, dest_dir_len);
}

extern "C" DWORD WINAPI ProxyVerFindFileW(DWORD flags, LPCWSTR file_name, LPCWSTR win_dir, LPCWSTR app_dir, LPWSTR cur_dir, PUINT cur_dir_len, LPWSTR dest_dir, PUINT dest_dir_len)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCWSTR, LPCWSTR, LPCWSTR, LPWSTR, PUINT, LPWSTR, PUINT);
    return CallVersionApi<Fn>("VerFindFileW", 0UL, flags, file_name, win_dir, app_dir, cur_dir, cur_dir_len, dest_dir, dest_dir_len);
}

extern "C" DWORD WINAPI ProxyVerInstallFileA(DWORD flags, LPCSTR source_file, LPCSTR dest_file, LPCSTR source_dir, LPCSTR dest_dir, LPCSTR cur_dir, LPSTR temp_file, PUINT temp_file_len)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCSTR, LPCSTR, LPCSTR, LPCSTR, LPCSTR, LPSTR, PUINT);
    return CallVersionApi<Fn>("VerInstallFileA", 0UL, flags, source_file, dest_file, source_dir, dest_dir, cur_dir, temp_file, temp_file_len);
}

extern "C" DWORD WINAPI ProxyVerInstallFileW(DWORD flags, LPCWSTR source_file, LPCWSTR dest_file, LPCWSTR source_dir, LPCWSTR dest_dir, LPCWSTR cur_dir, LPWSTR temp_file, PUINT temp_file_len)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPCWSTR, LPCWSTR, LPCWSTR, LPCWSTR, LPCWSTR, LPWSTR, PUINT);
    return CallVersionApi<Fn>("VerInstallFileW", 0UL, flags, source_file, dest_file, source_dir, dest_dir, cur_dir, temp_file, temp_file_len);
}

extern "C" DWORD WINAPI ProxyVerLanguageNameA(DWORD language, LPSTR buffer, DWORD buffer_length)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPSTR, DWORD);
    return CallVersionApi<Fn>("VerLanguageNameA", 0UL, language, buffer, buffer_length);
}

extern "C" DWORD WINAPI ProxyVerLanguageNameW(DWORD language, LPWSTR buffer, DWORD buffer_length)
{
    using Fn = DWORD (WINAPI*)(DWORD, LPWSTR, DWORD);
    return CallVersionApi<Fn>("VerLanguageNameW", 0UL, language, buffer, buffer_length);
}

extern "C" BOOL WINAPI ProxyVerQueryValueA(LPCVOID block, LPCSTR sub_block, LPVOID* buffer, PUINT length)
{
    using Fn = BOOL (WINAPI*)(LPCVOID, LPCSTR, LPVOID*, PUINT);
    return CallVersionApi<Fn>("VerQueryValueA", FALSE, block, sub_block, buffer, length);
}

extern "C" BOOL WINAPI ProxyVerQueryValueW(LPCVOID block, LPCWSTR sub_block, LPVOID* buffer, PUINT length)
{
    using Fn = BOOL (WINAPI*)(LPCVOID, LPCWSTR, LPVOID*, PUINT);
    return CallVersionApi<Fn>("VerQueryValueW", FALSE, block, sub_block, buffer, length);
}
