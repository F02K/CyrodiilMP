#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace CyrodiilMP::Bootstrap {

enum class ScanResultKind
{
    Direct,
    RipRelative
};

struct PatternDefinition
{
    std::string_view name;
    std::string_view pattern;
    std::string_view section;
    ScanResultKind result_kind = ScanResultKind::Direct;
    size_t result_offset = 0;
    size_t instruction_offset = 0;
    size_t displacement_offset = 0;
    size_t instruction_size = 0;
    intptr_t resolved_adjustment = 0;
    std::string_view note;
};

struct ScanResult
{
    std::string name;
    std::string section;
    uintptr_t match_address = 0;
    uintptr_t match_rva = 0;
    uintptr_t resolved_address = 0;
    uintptr_t resolved_rva = 0;
    size_t match_count = 0;
    bool found = false;
    bool ambiguous = false;
    std::string note;
};

std::vector<ScanResult> ScanPatterns(uintptr_t module_base, const std::vector<PatternDefinition>& definitions);
ScanResult ScanPattern(uintptr_t module_base, const PatternDefinition& definition);

}
