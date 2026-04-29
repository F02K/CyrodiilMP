#include "UEPatterns.hpp"

namespace CyrodiilMP::Bootstrap {

const std::vector<PatternDefinition>& GetUE53PatternDefinitions()
{
    static const std::vector<PatternDefinition> patterns = {
        {
            "GUObjectArrayCandidate",
            "48 83 EC 28 48 8D 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? 48 83 C4 28 E9 ?? ?? ?? ?? 48 83 EC 28 48 8D 0D ?? ?? ?? ?? FF 15",
            ".text",
            ScanResultKind::RipRelative,
            0,
            4,
            7,
            11,
            -4,
            "RIP-relative candidate seeded from the UE5.3 Oblivion Remastered startup path. The first LEA points four bytes into the GUObjectArray region, so the scanner reports the adjusted base candidate."
        },
        {
            "FName_ToString",
            "48 89 5C 24 10 48 89 74 24 18 57 48 83 EC 30 83 79 04 00 48 8B FA 8B 19 48 8B F1 0F 85 ?? ?? ?? ??",
            ".text",
            ScanResultKind::Direct,
            0,
            0,
            0,
            0,
            0,
            "Direct function candidate. Compare against UE4SS FName::ToString."
        },
        {
            "FName_FromWideChar",
            "48 89 5C 24 08 57 48 83 EC 30 48 8B D9 48 89 54 24 20 33 C9 41 8B F8 4C 8B D2",
            ".text",
            ScanResultKind::Direct,
            0,
            0,
            0,
            0,
            0,
            "Direct function candidate. Compare against UE4SS FName::FName(wchar_t*)."
        },
        {
            "StaticConstructObject_Internal",
            "48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 85 70 01 00 00 4C 8B 31 33 FF 44 8B 61 18 48 8B D9 4D 89 6B 10",
            ".text",
            ScanResultKind::Direct,
            0x21,
            0,
            0,
            0,
            0,
            "Direct function candidate."
        },
        {
            "ProcessEventCandidate",
            "C5 34 5C CC C5 04 5C E9 C5 4C 59 F6 C4 41 34 59 F9 C4 41 0C 58 F7 C4 41 14 59 FD C4 41 0C 58 F7",
            ".text",
            ScanResultKind::Direct,
            0,
            0,
            0,
            0,
            0,
            "Direct candidate seeded from current UE4SS ProcessEvent address. Treat as provisional."
        },
        {
            "ProcessLocalScriptFunctionCandidate",
            "06 D8 21 C4 43 7D 04 E3 14 C5 7F 12 EC C4 43 15 0C E4 48 C4 43 7D 04 E9 E1 C4 43 75 0C ED 12",
            ".text",
            ScanResultKind::Direct,
            0,
            0,
            0,
            0,
            0,
            "Direct candidate seeded from current UE4SS ProcessLocalScriptFunction address. Treat as provisional."
        }
    };

    return patterns;
}

}
