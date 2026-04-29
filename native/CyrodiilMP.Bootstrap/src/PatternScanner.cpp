#include "PatternScanner.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <algorithm>
#include <array>
#include <optional>
#include <sstream>

namespace CyrodiilMP::Bootstrap {

namespace {

struct PatternByte
{
    uint8_t value = 0;
    bool wildcard = false;
};

struct ModuleSection
{
    std::string name;
    uintptr_t address = 0;
    uintptr_t rva = 0;
    uintptr_t size = 0;
};

std::optional<uint8_t> ParseHexByte(std::string_view token)
{
    if (token.size() != 2)
    {
        return std::nullopt;
    }

    uint8_t value = 0;
    for (const char ch : token)
    {
        value <<= 4;
        if (ch >= '0' && ch <= '9')
        {
            value |= static_cast<uint8_t>(ch - '0');
        }
        else if (ch >= 'a' && ch <= 'f')
        {
            value |= static_cast<uint8_t>(10 + ch - 'a');
        }
        else if (ch >= 'A' && ch <= 'F')
        {
            value |= static_cast<uint8_t>(10 + ch - 'A');
        }
        else
        {
            return std::nullopt;
        }
    }

    return value;
}

std::vector<PatternByte> ParsePattern(std::string_view pattern)
{
    std::vector<PatternByte> bytes;
    std::istringstream stream{std::string(pattern)};
    std::string token;

    while (stream >> token)
    {
        if (token == "?" || token == "??")
        {
            bytes.push_back(PatternByte{0, true});
            continue;
        }

        const auto parsed = ParseHexByte(token);
        if (!parsed)
        {
            bytes.clear();
            return bytes;
        }

        bytes.push_back(PatternByte{*parsed, false});
    }

    return bytes;
}

bool PatternMatches(const uint8_t* candidate, const std::vector<PatternByte>& pattern)
{
    for (size_t i = 0; i < pattern.size(); ++i)
    {
        if (!pattern[i].wildcard && candidate[i] != pattern[i].value)
        {
            return false;
        }
    }

    return true;
}

std::array<size_t, 256> BuildByteHistogram(const ModuleSection& section)
{
    std::array<size_t, 256> histogram{};
    const auto* start = reinterpret_cast<const uint8_t*>(section.address);
    for (uintptr_t offset = 0; offset < section.size; ++offset)
    {
        ++histogram[start[offset]];
    }

    return histogram;
}

std::optional<size_t> SelectAnchorIndex(const ModuleSection& section, const std::vector<PatternByte>& pattern)
{
    const auto histogram = BuildByteHistogram(section);
    std::optional<size_t> anchor_index;
    size_t anchor_count = static_cast<size_t>(-1);

    for (size_t i = 0; i < pattern.size(); ++i)
    {
        if (pattern[i].wildcard)
        {
            continue;
        }

        const auto count = histogram[pattern[i].value];
        if (!anchor_index || count < anchor_count)
        {
            anchor_index = i;
            anchor_count = count;
        }
    }

    return anchor_index;
}

std::vector<uintptr_t> FindPattern(const ModuleSection& section, const std::vector<PatternByte>& pattern)
{
    std::vector<uintptr_t> matches;
    constexpr size_t kMaxReportedMatches = 128;
    if (pattern.empty() || section.size < pattern.size())
    {
        return matches;
    }

    const auto anchor_index = SelectAnchorIndex(section, pattern);
    if (!anchor_index)
    {
        return matches;
    }

    const auto* start = reinterpret_cast<const uint8_t*>(section.address);
    const auto end_offset = section.size - pattern.size();
    for (uintptr_t offset = 0; offset <= end_offset; ++offset)
    {
        if (start[offset + *anchor_index] != pattern[*anchor_index].value)
        {
            continue;
        }

        if (PatternMatches(start + offset, pattern))
        {
            matches.push_back(section.address + offset);
            if (matches.size() >= kMaxReportedMatches)
            {
                return matches;
            }
        }
    }

    return matches;
}

std::vector<ModuleSection> GetModuleSections(uintptr_t base)
{
    std::vector<ModuleSection> sections;
    const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE)
    {
        return sections;
    }

    const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS*>(base + static_cast<uintptr_t>(dos->e_lfanew));
    if (nt->Signature != IMAGE_NT_SIGNATURE)
    {
        return sections;
    }

    const auto* section = IMAGE_FIRST_SECTION(nt);
    for (WORD i = 0; i < nt->FileHeader.NumberOfSections; ++i)
    {
        char name_buffer[9]{};
        std::copy_n(reinterpret_cast<const char*>(section[i].Name), 8, name_buffer);

        const auto rva = static_cast<uintptr_t>(section[i].VirtualAddress);
        const auto virtual_size = static_cast<uintptr_t>(section[i].Misc.VirtualSize);
        const auto raw_size = static_cast<uintptr_t>(section[i].SizeOfRawData);
        const auto size = virtual_size > raw_size ? virtual_size : raw_size;
        if (size == 0)
        {
            continue;
        }

        sections.push_back(ModuleSection{
            std::string(name_buffer),
            base + rva,
            rva,
            size
        });
    }

    return sections;
}

const ModuleSection* FindSection(const std::vector<ModuleSection>& sections, std::string_view name)
{
    const auto found = std::find_if(sections.begin(), sections.end(), [name](const ModuleSection& section) {
        return section.name == name;
    });

    if (found == sections.end())
    {
        return nullptr;
    }

    return &(*found);
}

std::string FindSectionNameForAddress(const std::vector<ModuleSection>& sections, uintptr_t address)
{
    for (const auto& section : sections)
    {
        if (address >= section.address && address < section.address + section.size)
        {
            return section.name;
        }
    }

    return "outside-image";
}

uintptr_t ResolveRipRelative(uintptr_t match, const PatternDefinition& definition)
{
    const auto displacement_address = match + definition.displacement_offset;
    const auto displacement = *reinterpret_cast<const int32_t*>(displacement_address);
    return match + definition.instruction_offset + definition.instruction_size + static_cast<intptr_t>(displacement) + definition.resolved_adjustment;
}

ScanResult ScanOne(uintptr_t base, const std::vector<ModuleSection>& sections, const PatternDefinition& definition)
{
    ScanResult result;
    result.name = std::string(definition.name);
    result.note = std::string(definition.note);

    const auto* section = FindSection(sections, definition.section);
    if (section == nullptr)
    {
        result.section = "missing-section";
        return result;
    }

    result.section = section->name;
    const auto pattern = ParsePattern(definition.pattern);
    if (pattern.empty())
    {
        result.section = "invalid-pattern";
        return result;
    }

    const auto matches = FindPattern(*section, pattern);
    result.match_count = matches.size();
    result.found = !matches.empty();
    result.ambiguous = matches.size() > 1;
    if (matches.empty())
    {
        return result;
    }

    result.match_address = matches.front() - definition.result_offset;
    result.match_rva = result.match_address - base;
    if (definition.result_kind == ScanResultKind::RipRelative)
    {
        result.resolved_address = ResolveRipRelative(result.match_address, definition);
        result.resolved_rva = result.resolved_address - base;
        result.section += " -> " + FindSectionNameForAddress(sections, result.resolved_address);
    }
    else
    {
        result.resolved_address = result.match_address;
        result.resolved_rva = result.match_rva;
    }

    return result;
}

}

std::vector<ScanResult> ScanPatterns(uintptr_t module_base, const std::vector<PatternDefinition>& definitions)
{
    std::vector<ScanResult> results;
    results.reserve(definitions.size());

    for (const auto& definition : definitions)
    {
        results.push_back(ScanPattern(module_base, definition));
    }

    return results;
}

ScanResult ScanPattern(uintptr_t module_base, const PatternDefinition& definition)
{
    const auto sections = GetModuleSections(module_base);
    if (sections.empty())
    {
        ScanResult result;
        result.name = std::string(definition.name);
        result.section = "no-module-sections";
        result.note = std::string(definition.note);
        return result;
    }

    return ScanOne(module_base, sections, definition);
}

}
