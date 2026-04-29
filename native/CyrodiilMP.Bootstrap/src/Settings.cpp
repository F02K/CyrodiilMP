#include "Settings.hpp"

#include <cctype>
#include <fstream>
#include <string>
#include <utility>

namespace CyrodiilMP::Bootstrap {

namespace {

std::string Trim(std::string value)
{
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos)
    {
        return {};
    }

    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::string ToLower(std::string value)
{
    for (auto& ch : value)
    {
        ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
    }

    return value;
}

bool ParseBool(std::string value, bool fallback)
{
    value = ToLower(Trim(std::move(value)));
    if (value == "1" || value == "true" || value == "yes" || value == "on" || value == "enabled")
    {
        return true;
    }

    if (value == "0" || value == "false" || value == "no" || value == "off" || value == "disabled")
    {
        return false;
    }

    return fallback;
}

}

void EnsureSettingsFile(const std::filesystem::path& settings_path)
{
    if (std::filesystem::exists(settings_path))
    {
        return;
    }

    std::error_code ignored;
    std::filesystem::create_directories(settings_path.parent_path(), ignored);

    std::ofstream output(settings_path, std::ios::binary | std::ios::trunc);
    output
        << "# CyrodiilMP standalone bootstrap settings\n"
        << "# Set EnableConsole=false to hide the native debug console.\n"
        << "# Set EnableUEPatternScan=false if a game update makes startup scanning unstable.\n"
        << "# Set EnableNirnLabUI=false to disable the Chromium UI backend.\n"
        << "# Set ShowMainMenuButton=false to keep the backend available but hide the prototype menu button.\n"
        << "[Debug]\n"
        << "EnableConsole=true\n"
        << "\n"
        << "[UEBridge]\n"
        << "EnableUEPatternScan=true\n"
        << "\n"
        << "[UI]\n"
        << "EnableNirnLabUI=true\n"
        << "ShowMainMenuButton=true\n";
}

BootstrapSettings LoadSettings(const std::filesystem::path& settings_path)
{
    EnsureSettingsFile(settings_path);

    BootstrapSettings settings;
    std::ifstream input(settings_path, std::ios::binary);
    if (!input)
    {
        return settings;
    }

    std::string section;
    std::string line;
    while (std::getline(input, line))
    {
        const auto comment = line.find_first_of("#;");
        if (comment != std::string::npos)
        {
            line = line.substr(0, comment);
        }

        line = Trim(line);
        if (line.empty())
        {
            continue;
        }

        if (line.front() == '[' && line.back() == ']')
        {
            section = ToLower(Trim(line.substr(1, line.size() - 2)));
            continue;
        }

        const auto equals = line.find('=');
        if (equals == std::string::npos)
        {
            continue;
        }

        auto key = ToLower(Trim(line.substr(0, equals)));
        auto value = Trim(line.substr(equals + 1));
        if (section == "debug" && key == "enableconsole")
        {
            settings.enable_debug_console = ParseBool(value, settings.enable_debug_console);
        }
        else if (section == "uebridge" && key == "enableuepatternscan")
        {
            settings.enable_ue_pattern_scan = ParseBool(value, settings.enable_ue_pattern_scan);
        }
        else if (section == "ui" && key == "enablenirnlabui")
        {
            settings.enable_nirnlab_ui = ParseBool(value, settings.enable_nirnlab_ui);
        }
        else if (section == "ui" && key == "showmainmenubutton")
        {
            settings.show_main_menu_button = ParseBool(value, settings.show_main_menu_button);
        }
    }

    return settings;
}

}
