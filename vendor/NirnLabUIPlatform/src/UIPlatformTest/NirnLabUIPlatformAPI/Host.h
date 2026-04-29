#pragma once

#include <cstdint>

namespace NL::UI
{
    enum class HostRuntime : std::uint32_t
    {
        Unknown = 0,
        SkyrimSKSE = 1,
        OblivionRemastered = 2,
    };

    struct HostInfo
    {
        std::uint32_t structSize = sizeof(HostInfo);
        HostRuntime runtime = HostRuntime::Unknown;
        const char* runtimeName = "Unknown";
        const char* gameName = "";
        const char* integrationName = "NirnLabUIPlatform";
    };

    inline constexpr HostInfo GetCompileTimeHostInfo()
    {
#if defined(NL_UI_HOST_OBLIVION_REMASTERED)
        return {
            sizeof(HostInfo),
            HostRuntime::OblivionRemastered,
            "OblivionRemastered",
            "Oblivion Remastered",
            "Oblivion Remastered"
        };
#elif defined(NL_UI_HOST_SKYRIM_SKSE)
        return {
            sizeof(HostInfo),
            HostRuntime::SkyrimSKSE,
            "SkyrimSKSE",
            "Skyrim Special Edition",
            "SKSE"
        };
#else
        return {
            sizeof(HostInfo),
            HostRuntime::SkyrimSKSE,
            "SkyrimSKSE",
            "Skyrim Special Edition",
            "SKSE"
        };
#endif
    }
}
