#include "UEBridge.hpp"

#include "Log.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdint>
#include <sstream>

namespace CyrodiilMP::Bootstrap {

namespace {

std::filesystem::path g_game_exe_path;

std::string Hex(uintptr_t value)
{
    std::ostringstream stream;
    stream << "0x" << std::hex << value;
    return stream.str();
}

}

void UEBridge::Initialize(const std::filesystem::path& game_exe_path)
{
    g_game_exe_path = game_exe_path;
    Log::Write("UEBridge initialized for " + g_game_exe_path.string());
}

void UEBridge::CaptureStartupSnapshot()
{
    const auto* module = GetModuleHandleW(nullptr);
    if (module == nullptr)
    {
        Log::Write("UEBridge snapshot failed: main module handle unavailable");
        return;
    }

    MODULEINFO info{};
    // Avoid depending on psapi.lib for now; use the PE headers for a light startup snapshot.
    const auto base = reinterpret_cast<uintptr_t>(module);
    const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE)
    {
        Log::Write("UEBridge snapshot failed: invalid DOS header");
        return;
    }

    const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS*>(base + static_cast<uintptr_t>(dos->e_lfanew));
    if (nt->Signature != IMAGE_NT_SIGNATURE)
    {
        Log::Write("UEBridge snapshot failed: invalid NT header");
        return;
    }

    const auto image_size = static_cast<uintptr_t>(nt->OptionalHeader.SizeOfImage);
    Log::Write("UEBridge snapshot main_module_base=" + Hex(base) + " size=" + Hex(image_size));
    Log::Write("UEBridge TODO: add UE5.3 pattern scan for GUObjectArray, FName::ToString, ProcessEvent, and UWorld");
}

}
