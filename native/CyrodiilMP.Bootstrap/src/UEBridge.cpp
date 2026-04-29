#include "UEBridge.hpp"

#include "Log.hpp"
#include "PatternScanner.hpp"
#include "UEPatterns.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace CyrodiilMP::Bootstrap {

namespace {

std::filesystem::path g_game_exe_path;
UEBridgeSettings g_settings;

std::string Hex(uintptr_t value)
{
    std::ostringstream stream;
    stream << "0x" << std::hex << value;
    return stream.str();
}

std::string JsonEscape(std::string_view value)
{
    std::string escaped;
    escaped.reserve(value.size());

    for (const char ch : value)
    {
        switch (ch)
        {
        case '\\':
            escaped += "\\\\";
            break;
        case '"':
            escaped += "\\\"";
            break;
        case '\n':
            escaped += "\\n";
            break;
        case '\r':
            escaped += "\\r";
            break;
        case '\t':
            escaped += "\\t";
            break;
        default:
            escaped += ch;
            break;
        }
    }

    return escaped;
}

void WriteScanResultsJson(const std::vector<ScanResult>& results)
{
    if (g_settings.output_directory.empty())
    {
        return;
    }

    std::error_code ignored;
    std::filesystem::create_directories(g_settings.output_directory, ignored);
    const auto output_path = g_settings.output_directory / "ue-pattern-scan.json";
    std::ofstream output(output_path, std::ios::binary | std::ios::trunc);
    if (!output)
    {
        Log::Write("UEBridge scan could not write " + output_path.string());
        return;
    }

    output << "{\n";
    output << "  \"gameExe\": \"" << JsonEscape(g_game_exe_path.string()) << "\",\n";
    output << "  \"patterns\": [\n";
    for (size_t i = 0; i < results.size(); ++i)
    {
        const auto& result = results[i];
        output << "    {\n";
        output << "      \"name\": \"" << JsonEscape(result.name) << "\",\n";
        output << "      \"found\": " << (result.found ? "true" : "false") << ",\n";
        output << "      \"ambiguous\": " << (result.ambiguous ? "true" : "false") << ",\n";
        output << "      \"matchCount\": " << result.match_count << ",\n";
        output << "      \"section\": \"" << JsonEscape(result.section) << "\",\n";
        output << "      \"matchAddress\": \"" << Hex(result.match_address) << "\",\n";
        output << "      \"matchRva\": \"" << Hex(result.match_rva) << "\",\n";
        output << "      \"resolvedAddress\": \"" << Hex(result.resolved_address) << "\",\n";
        output << "      \"resolvedRva\": \"" << Hex(result.resolved_rva) << "\",\n";
        output << "      \"note\": \"" << JsonEscape(result.note) << "\"\n";
        output << "    }" << (i + 1 == results.size() ? "\n" : ",\n");
    }
    output << "  ]\n";
    output << "}\n";

    Log::Write("UEBridge scan wrote " + output_path.string());
}

void LogScanResult(const ScanResult& result)
{
    if (!result.found)
    {
        Log::Write("UEBridge scan " + result.name + " not_found section=" + result.section);
        return;
    }

    const auto status = result.ambiguous ? "ambiguous" : "found";
    Log::Write(
        "UEBridge scan " + result.name +
        " " + status +
        " matches=" + std::to_string(result.match_count) +
        " match_rva=" + Hex(result.match_rva) +
        " resolved_rva=" + Hex(result.resolved_rva) +
        " resolved_address=" + Hex(result.resolved_address) +
        " section=" + result.section);
}

void RunPatternScan(uintptr_t base)
{
    if (!g_settings.enable_pattern_scan)
    {
        Log::Write("UEBridge pattern scan disabled by settings");
        return;
    }

    const auto& patterns = GetUE53PatternDefinitions();
    Log::Write("UEBridge pattern scan starting definitions=" + std::to_string(patterns.size()));

    std::vector<ScanResult> results;
    results.reserve(patterns.size());
    for (const auto& pattern : patterns)
    {
        Log::Write("UEBridge scan " + std::string(pattern.name) + " scanning");
        auto result = ScanPattern(base, pattern);
        LogScanResult(result);
        results.push_back(std::move(result));
    }

    WriteScanResultsJson(results);
}

}

void UEBridge::Initialize(const std::filesystem::path& game_exe_path, UEBridgeSettings settings)
{
    g_game_exe_path = game_exe_path;
    g_settings = std::move(settings);
    Log::Write("UEBridge initialized for " + g_game_exe_path.string());
    Log::Write(std::string("UEBridge pattern scan setting: ") + (g_settings.enable_pattern_scan ? "enabled" : "disabled"));
}

void UEBridge::CaptureStartupSnapshot()
{
    const auto* module = GetModuleHandleW(nullptr);
    if (module == nullptr)
    {
        Log::Write("UEBridge snapshot failed: main module handle unavailable");
        return;
    }

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
    RunPatternScan(base);
}

}
