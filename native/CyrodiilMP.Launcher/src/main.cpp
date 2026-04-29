#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>

#include <filesystem>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct Options
{
    std::wstring game_exe;
    std::wstring bootstrap_dll;
    std::wstring game_args;
    std::wstring process_name = L"OblivionRemastered-Win64-Shipping.exe";
    bool existing = false;
    bool suspended = false;
};

void PrintUsage()
{
    std::wcout
        << L"CyrodiilMP.Launcher\n"
        << L"\n"
        << L"Launch and inject CyrodiilMP.Bootstrap.dll without UE4SS.\n"
        << L"\n"
        << L"Usage:\n"
        << L"  CyrodiilMP.Launcher.exe --game-exe <path> --bootstrap-dll <path> [--game-args <args>]\n"
        << L"  CyrodiilMP.Launcher.exe --existing --process-name <exe> --bootstrap-dll <path>\n"
        << L"\n";
}

std::wstring ArgValue(const std::vector<std::wstring>& args, size_t& index)
{
    if (index + 1 >= args.size())
    {
        throw std::runtime_error("missing argument value");
    }
    ++index;
    return args[index];
}

Options ParseArgs(int argc, wchar_t** argv)
{
    Options options;
    std::vector<std::wstring> args;
    for (int i = 1; i < argc; ++i)
    {
        args.emplace_back(argv[i]);
    }

    for (size_t i = 0; i < args.size(); ++i)
    {
        if (args[i] == L"--game-exe")
        {
            options.game_exe = ArgValue(args, i);
        }
        else if (args[i] == L"--bootstrap-dll")
        {
            options.bootstrap_dll = ArgValue(args, i);
        }
        else if (args[i] == L"--game-args")
        {
            options.game_args = ArgValue(args, i);
        }
        else if (args[i] == L"--existing")
        {
            options.existing = true;
        }
        else if (args[i] == L"--process-name")
        {
            options.process_name = ArgValue(args, i);
        }
        else if (args[i] == L"--suspended")
        {
            options.suspended = true;
        }
        else if (args[i] == L"--help" || args[i] == L"-h")
        {
            PrintUsage();
            ExitProcess(0);
        }
        else
        {
            throw std::runtime_error("unknown argument");
        }
    }

    if (options.bootstrap_dll.empty())
    {
        throw std::runtime_error("--bootstrap-dll is required");
    }

    if (!options.existing && options.game_exe.empty())
    {
        throw std::runtime_error("--game-exe is required unless --existing is used");
    }

    return options;
}

std::wstring Quote(const std::wstring& value)
{
    return L"\"" + value + L"\"";
}

std::optional<DWORD> FindProcessId(const std::wstring& process_name)
{
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
    {
        return std::nullopt;
    }

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);
    if (!Process32FirstW(snapshot, &entry))
    {
        CloseHandle(snapshot);
        return std::nullopt;
    }

    do
    {
        if (_wcsicmp(entry.szExeFile, process_name.c_str()) == 0)
        {
            const DWORD pid = entry.th32ProcessID;
            CloseHandle(snapshot);
            return pid;
        }
    } while (Process32NextW(snapshot, &entry));

    CloseHandle(snapshot);
    return std::nullopt;
}

bool InjectDll(HANDLE process, const std::filesystem::path& dll_path)
{
    const auto dll_text = dll_path.wstring();
    const auto bytes = (dll_text.size() + 1) * sizeof(wchar_t);

    void* remote_path = VirtualAllocEx(process, nullptr, bytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (remote_path == nullptr)
    {
        std::wcerr << L"VirtualAllocEx failed: " << GetLastError() << L"\n";
        return false;
    }

    if (!WriteProcessMemory(process, remote_path, dll_text.c_str(), bytes, nullptr))
    {
        std::wcerr << L"WriteProcessMemory failed: " << GetLastError() << L"\n";
        VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
        return false;
    }

    HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
    auto* load_library = reinterpret_cast<LPTHREAD_START_ROUTINE>(GetProcAddress(kernel32, "LoadLibraryW"));
    if (load_library == nullptr)
    {
        std::wcerr << L"GetProcAddress(LoadLibraryW) failed: " << GetLastError() << L"\n";
        VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
        return false;
    }

    HANDLE thread = CreateRemoteThread(process, nullptr, 0, load_library, remote_path, 0, nullptr);
    if (thread == nullptr)
    {
        std::wcerr << L"CreateRemoteThread failed: " << GetLastError() << L"\n";
        VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
        return false;
    }

    WaitForSingleObject(thread, 15000);
    DWORD exit_code = 0;
    GetExitCodeThread(thread, &exit_code);
    CloseHandle(thread);
    VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);

    if (exit_code == 0)
    {
        std::wcerr << L"LoadLibraryW returned null in remote process\n";
        return false;
    }

    return true;
}

int LaunchAndInject(const Options& options)
{
    auto command_line = Quote(options.game_exe);
    if (!options.game_args.empty())
    {
        command_line += L" ";
        command_line += options.game_args;
    }

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    auto mutable_command_line = command_line;
    const DWORD create_flags = CREATE_SUSPENDED;

    const auto working_dir = std::filesystem::path(options.game_exe).parent_path().wstring();
    if (!CreateProcessW(
            options.game_exe.c_str(),
            mutable_command_line.data(),
            nullptr,
            nullptr,
            FALSE,
            create_flags,
            nullptr,
            working_dir.c_str(),
            &startup,
            &process))
    {
        std::wcerr << L"CreateProcessW failed: " << GetLastError() << L"\n";
        return 1;
    }

    std::wcout << L"Started process pid=" << process.dwProcessId << L"\n";
    const bool injected = InjectDll(process.hProcess, options.bootstrap_dll);
    if (!injected)
    {
        TerminateProcess(process.hProcess, 1);
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        return 1;
    }

    std::wcout << L"Injected " << options.bootstrap_dll << L"\n";
    if (!options.suspended)
    {
        ResumeThread(process.hThread);
        std::wcout << L"Game resumed\n";
    }
    else
    {
        std::wcout << L"Game left suspended by request\n";
    }

    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return 0;
}

int InjectExisting(const Options& options)
{
    const auto pid = FindProcessId(options.process_name);
    if (!pid)
    {
        std::wcerr << L"Process not found: " << options.process_name << L"\n";
        return 1;
    }

    HANDLE process = OpenProcess(PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ, FALSE, *pid);
    if (process == nullptr)
    {
        std::wcerr << L"OpenProcess failed: " << GetLastError() << L"\n";
        return 1;
    }

    const bool injected = InjectDll(process, options.bootstrap_dll);
    CloseHandle(process);

    if (!injected)
    {
        return 1;
    }

    std::wcout << L"Injected existing process pid=" << *pid << L"\n";
    return 0;
}

}

int wmain(int argc, wchar_t** argv)
{
    try
    {
        const auto options = ParseArgs(argc, argv);
        if (options.existing)
        {
            return InjectExisting(options);
        }

        return LaunchAndInject(options);
    }
    catch (const std::exception& ex)
    {
        std::cerr << "Error: " << ex.what() << "\n\n";
        PrintUsage();
        return 1;
    }
}
