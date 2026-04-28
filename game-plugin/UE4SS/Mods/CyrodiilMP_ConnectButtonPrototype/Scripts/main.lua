local serverHost = "127.0.0.1"
local serverPort = "27015"
local probeDirName = "CyrodiilMP_MenuProbe"
local bridgeExe = "CyrodiilMP/ClientBridge/CyrodiilMP.ClientBridge.exe"
local autoProbeRuns = 0
local registeredHooks = {}

local function safe_tostring(value)
    local ok, result = pcall(function()
        if value == nil then return "" end
        return tostring(value)
    end)
    if ok then return result end
    return "<error>"
end

local function safe_full_name(object)
    if object == nil then return "" end
    local ok, result = pcall(function()
        if object:IsValid() then
            return object:GetFullName()
        end
        return ""
    end)
    if ok then return result end
    return ""
end

local function safe_class_name(object)
    if object == nil then return "" end
    local ok, result = pcall(function()
        if object:IsValid() then
            local class = object:GetClass()
            if class and class:IsValid() then
                return class:GetFullName()
            end
        end
        return ""
    end)
    if ok then return result end
    return ""
end

local function write_lines(file_name, lines)
    os.execute("mkdir " .. probeDirName)
    local file = io.open(probeDirName .. "/" .. file_name, "w")
    if not file then
        print("[CyrodiilMP_MenuProbe] Could not write " .. file_name)
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()
end

local function append_line(file_name, line)
    os.execute("mkdir " .. probeDirName)
    local file = io.open(probeDirName .. "/" .. file_name, "a")
    if not file then
        print("[CyrodiilMP_MenuProbe] Could not append " .. file_name)
        return
    end

    file:write(line .. "\n")
    file:close()
end

local function csv_escape(value)
    value = safe_tostring(value)
    value = value:gsub('"', '""')
    return '"' .. value .. '"'
end

local function shell_quote(value)
    value = safe_tostring(value)
    value = value:gsub('"', "'")
    return '"' .. value .. '"'
end

local function append_matches(lines, short_class_name, label, pattern)
    local ok, objects = pcall(function()
        return FindAllOf(short_class_name)
    end)

    if not ok or objects == nil then
        table.insert(lines, csv_escape(label) .. "," .. csv_escape(short_class_name) .. "," .. csv_escape("<FindAllOf failed>") .. "," .. csv_escape(""))
        return
    end

    local matched = 0
    for _, object in pairs(objects) do
        local full_name = safe_full_name(object)
        if string.find(full_name, pattern) then
            matched = matched + 1
            table.insert(lines, table.concat({
                csv_escape(label),
                csv_escape(short_class_name),
                csv_escape(full_name),
                csv_escape(safe_class_name(object))
            }, ","))
        end
    end

    print("[CyrodiilMP_MenuProbe] " .. label .. ": " .. tostring(matched) .. " matches from " .. short_class_name)
end

local function run_menu_probe()
    autoProbeRuns = autoProbeRuns + 1
    print("[CyrodiilMP_MenuProbe] Probing main-menu widget references.")

    local lines = {}
    table.insert(lines, "Label,ClassQuery,FullName,ClassName")
    append_matches(lines, "UserWidget", "main-menu user widgets", "MainMenu")
    append_matches(lines, "UserWidget", "legacy main menu", "WBP_LegacyMenu_Main")
    append_matches(lines, "Widget", "main wrapper widgets", "main_")
    append_matches(lines, "Widget", "main menu button widgets", "WBP_MainMenu_Button")
    append_matches(lines, "Widget", "internal clickable buttons", "InternalRootButtonBase")
    append_matches(lines, "CommonButtonInternalBase", "common internal buttons", "InternalRootButtonBase")
    append_matches(lines, "CommonButtonBase", "common buttons", "WBP_MainMenu_Button")

    write_lines("menu-probe.csv", lines)
    write_lines("status.md", {
        "# CyrodiilMP Menu Probe",
        "",
        "The connect-button prototype loaded and wrote this file from UE4SS.",
        "",
        "- Auto probe run: " .. tostring(autoProbeRuns),
        "- Server target: " .. serverHost .. ":" .. serverPort,
        "",
        "If the in-game console says `cyro_menu_probe` or `cyro_connect` does not exist, that is okay for now. This file proves the mod is running without relying on console commands."
    })
    print("[CyrodiilMP_MenuProbe] Wrote " .. probeDirName .. "/menu-probe.csv")
end

local function connect_requested(reason, context)
    local context_name = safe_full_name(context)
    local timestamp = os.date("%Y-%m-%dT%H:%M:%S")

    print("[CyrodiilMP] Connect requested by " .. reason)
    print("[CyrodiilMP] Target server: " .. serverHost .. ":" .. serverPort)
    if context_name ~= "" then
        print("[CyrodiilMP] Context: " .. context_name)
    end

    write_lines("connect-request.md", {
        "# CyrodiilMP Connect Request",
        "",
        "A menu click reached the CyrodiilMP UE4SS prototype.",
        "",
        "- Time: " .. timestamp,
        "- Reason: " .. reason,
        "- Target server: " .. serverHost .. ":" .. serverPort,
        "- Context: `" .. context_name .. "`",
        "",
        "This is not a real network client yet. It proves the main-menu click hook can call CyrodiilMP code."
    })

    append_line("connect-events.csv", table.concat({
        csv_escape(timestamp),
        csv_escape(reason),
        csv_escape(serverHost .. ":" .. serverPort),
        csv_escape(context_name)
    }, ","))

    local resultPath = probeDirName .. "/client-bridge-result.json"
    local command = table.concat({
        shell_quote(bridgeExe),
        "--host",
        shell_quote(serverHost),
        "--port",
        shell_quote(serverPort),
        "--name",
        shell_quote("OblivionMenu"),
        "--reason",
        shell_quote(reason),
        "--timeout-ms",
        "1800",
        "--out",
        shell_quote(resultPath)
    }, " ")

    print("[CyrodiilMP] Launching client bridge: " .. command)
    local exit_code = os.execute(command)
    write_lines("client-bridge-launch.md", {
        "# CyrodiilMP Client Bridge Launch",
        "",
        "- Time: " .. os.date("%Y-%m-%dT%H:%M:%S"),
        "- Command: `" .. command .. "`",
        "- Exit code: `" .. safe_tostring(exit_code) .. "`",
        "- Result path: `" .. resultPath .. "`"
    })
end

local function register_click_hook(function_path, reason, connect_on_call)
    local ok, pre_id, post_id = pcall(function()
        return RegisterHook(function_path, function(context)
            local actual_context = nil
            local ok_context, result = pcall(function()
                if context ~= nil and context.get ~= nil then
                    return context:get()
                end
                return context
            end)

            if ok_context then
                actual_context = result
            end

            local context_name = safe_full_name(actual_context)
            print("[CyrodiilMP_MenuProbe] Click hook fired: " .. reason .. " / " .. context_name)
            append_line("click-events.csv", table.concat({
                csv_escape(os.date("%Y-%m-%dT%H:%M:%S")),
                csv_escape(reason),
                csv_escape(context_name)
            }, ","))

            if connect_on_call then
                connect_requested(reason, actual_context)
            end
        end)
    end)

    local status = ok and "registered" or "failed"
    local detail = ok and ("pre=" .. safe_tostring(pre_id) .. " post=" .. safe_tostring(post_id)) or safe_tostring(pre_id)
    table.insert(registeredHooks, {
        status = status,
        path = function_path,
        detail = detail
    })
    print("[CyrodiilMP_MenuProbe] Hook " .. status .. ": " .. function_path .. " " .. detail)
end

local function should_connect_for_context(context_name)
    return string.find(context_name, "main_credits_wrapper") ~= nil
end

local function register_common_button_hook(function_path, reason)
    local ok, pre_id, post_id = pcall(function()
        return RegisterHook(function_path, function(context)
            local actual_context = nil
            local ok_context, result = pcall(function()
                if context ~= nil and context.get ~= nil then
                    return context:get()
                end
                return context
            end)

            if ok_context then
                actual_context = result
            end

            local context_name = safe_full_name(actual_context)
            print("[CyrodiilMP_MenuProbe] CommonUI hook fired: " .. reason .. " / " .. context_name)
            append_line("click-events.csv", table.concat({
                csv_escape(os.date("%Y-%m-%dT%H:%M:%S")),
                csv_escape(reason),
                csv_escape(context_name)
            }, ","))

            if should_connect_for_context(context_name) then
                connect_requested(reason .. " credits-filter", actual_context)
            end
        end)
    end)

    local status = ok and "registered" or "failed"
    local detail = ok and ("pre=" .. safe_tostring(pre_id) .. " post=" .. safe_tostring(post_id)) or safe_tostring(pre_id)
    table.insert(registeredHooks, {
        status = status,
        path = function_path,
        detail = detail
    })
    print("[CyrodiilMP_MenuProbe] Hook " .. status .. ": " .. function_path .. " " .. detail)
end

local function write_hook_status()
    local lines = {
        "# CyrodiilMP Click Hook Status",
        "",
        "The current prototype hooks CommonUI button clicks and filters the existing Credits menu button as a temporary Connect trigger.",
        ""
    }

    for _, hook in ipairs(registeredHooks) do
        table.insert(lines, "- " .. hook.status .. ": `" .. hook.path .. "` (" .. hook.detail .. ")")
    end

    write_lines("hook-status.md", lines)
end

print("[CyrodiilMP_ConnectButtonPrototype] Loaded.")
print("[CyrodiilMP_ConnectButtonPrototype] Discovery prototype loaded. It can probe menu widgets and receive connect requests.")
print("[CyrodiilMP_ConnectButtonPrototype] Console commands may not route in this game build, so menu probes also run automatically.")
print("[CyrodiilMP_ConnectButtonPrototype] Optional console command: cyro_connect")
print("[CyrodiilMP_ConnectButtonPrototype] Optional console command: cyro_menu_probe")

write_lines("click-events.csv", { "Time,Reason,Context" })
write_lines("connect-events.csv", { "Time,Reason,Target,Context" })

register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", "CommonButtonBase HandleButtonClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:BP_OnClicked", "CommonButtonBase BP_OnClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonPressed", "CommonButtonBase HandleButtonPressed")

write_hook_status()

ExecuteWithDelay(20000, function()
    print("[CyrodiilMP_ConnectButtonPrototype] Auto menu probe after 20 seconds.")
    run_menu_probe()
end)

ExecuteWithDelay(45000, function()
    print("[CyrodiilMP_ConnectButtonPrototype] Auto menu probe after 45 seconds.")
    run_menu_probe()
end)

ExecuteWithDelay(90000, function()
    print("[CyrodiilMP_ConnectButtonPrototype] Auto menu probe after 90 seconds.")
    run_menu_probe()
end)

RegisterProcessConsoleExecPreHook(function(Context, Cmd, CommandParts, Ar, Executor)
    local command = tostring(Cmd):lower()
    if command == "cyro_connect" or command == "cyro_connect_server" then
        connect_requested("console command", Context)
        return true
    end

    if command == "cyro_menu_probe" or command == "cyro_probe_menu" then
        run_menu_probe()
        return true
    end
end)
