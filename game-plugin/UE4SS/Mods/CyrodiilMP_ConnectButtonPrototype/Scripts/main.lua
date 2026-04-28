local serverHost = "127.0.0.1"
local serverPort = "27015"
local probeDirName = "CyrodiilMP_MenuProbe"
local bridgeExe = "CyrodiilMP\\ClientBridge\\CyrodiilMP.ClientBridge.exe"
local enableAutoMenuProbe = false
local logNonCreditsClicks = false
local autoProbeRuns = 0
local registeredHooks = {}
local connectInProgress = false

local BUTTON_WRAPPER_CLASS_PATH = "/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C"
local BUTTON_LAYOUT_CLASS_SHORT = "WBP_Modern_MainMenu_ButtonLayout_C"

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
    local file = io.open(probeDirName .. "/" .. file_name, "w")
    if not file then
        print("[CyrodiilMP] Could not write " .. file_name)
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()
end

local function append_line(file_name, line)
    local file = io.open(probeDirName .. "/" .. file_name, "a")
    if not file then
        print("[CyrodiilMP] Could not append " .. file_name)
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

local function windows_path(value)
    value = safe_tostring(value)
    return value:gsub("/", "\\")
end

local function powershell_quote(value)
    value = safe_tostring(value)
    value = value:gsub("'", "''")
    return "'" .. value .. "'"
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

    print("[CyrodiilMP] " .. label .. ": " .. tostring(matched) .. " matches")
end

local function run_menu_probe()
    autoProbeRuns = autoProbeRuns + 1
    print("[CyrodiilMP] Probing main-menu widget references (run " .. autoProbeRuns .. ")")

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
        "- Auto probe run: " .. tostring(autoProbeRuns),
        "- Server target: " .. serverHost .. ":" .. serverPort,
    })
    print("[CyrodiilMP] Wrote " .. probeDirName .. "/menu-probe.csv")
end

local function record_click_event(reason, context_name)
    append_line("click-events.csv", table.concat({
        csv_escape(os.date("%Y-%m-%dT%H:%M:%S")),
        csv_escape(reason),
        csv_escape(context_name)
    }, ","))
end

local function connect_requested(reason, context)
    if connectInProgress then
        print("[CyrodiilMP] Connect already in progress, ignoring duplicate trigger.")
        return
    end
    connectInProgress = true

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

    local resultPath = windows_path(probeDirName .. "/client-bridge-result.json")
    local bridgeCommand = table.concat({
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

    local launcherPath = windows_path(probeDirName .. "/launch-client-bridge.ps1")
    local hiddenLaunchCommand = table.concat({
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File",
        shell_quote(launcherPath)
    }, " ")

    write_lines("launch-client-bridge.ps1", {
        "$ErrorActionPreference = 'Stop'",
        "$win64Path = Split-Path -Parent (Split-Path -Parent $PSCommandPath)",
        "Set-Location -LiteralPath $win64Path",
        "& " .. powershell_quote(".\\CyrodiilMP\\ClientBridge\\CyrodiilMP.ClientBridge.exe")
            .. " --host " .. powershell_quote(serverHost)
            .. " --port " .. powershell_quote(serverPort)
            .. " --name " .. powershell_quote("OblivionMenu")
            .. " --reason " .. powershell_quote(reason)
            .. " --timeout-ms 1800"
            .. " --out " .. powershell_quote(".\\CyrodiilMP_MenuProbe\\client-bridge-result.json")
            .. " *> " .. powershell_quote(".\\CyrodiilMP_MenuProbe\\client-bridge-output.txt"),
        "$exitCode = $LASTEXITCODE",
        "Add-Content -LiteralPath " .. powershell_quote(".\\CyrodiilMP_MenuProbe\\client-bridge-output.txt") .. " -Value ('EXITCODE:' + $exitCode)",
        "exit $exitCode"
    })

    print("[CyrodiilMP] Launching client bridge hidden helper: " .. launcherPath)
    local exit_code = os.execute(hiddenLaunchCommand)
    write_lines("client-bridge-launch.md", {
        "# CyrodiilMP Client Bridge Launch",
        "",
        "- Time: " .. os.date("%Y-%m-%dT%H:%M:%S"),
        "- Launcher: `" .. launcherPath .. "`",
        "- Launch command: `" .. hiddenLaunchCommand .. "`",
        "- Bridge command: `" .. bridgeCommand .. "`",
        "- Exit code: `" .. safe_tostring(exit_code) .. "`",
        "- Result path: `" .. resultPath .. "`"
    })

    connectInProgress = false
end

local function relabel_credits_button()
    local textblocks = FindAllOf("TextBlock")
    if not textblocks then
        print("[CyrodiilMP] relabel: FindAllOf(TextBlock) returned nil")
        return
    end

    local relabelled = 0
    for _, tb in pairs(textblocks) do
        local full_name = safe_full_name(tb)
        if string.find(full_name, "main_credits_wrapper") then
            local ok = pcall(function()
                tb:SetText(FText("MULTIPLAYER"))
            end)
            if ok then
                relabelled = relabelled + 1
                print("[CyrodiilMP] Relabelled Credits TextBlock: " .. full_name)
            end
        end
    end

    if relabelled == 0 then
        print("[CyrodiilMP] relabel: no Credits TextBlock found")
    end
end

local function add_multiplayer_button()
    local layout = FindFirstOf(BUTTON_LAYOUT_CLASS_SHORT)
    if not layout or not layout:IsValid() then
        print("[CyrodiilMP] add_button: layout panel (" .. BUTTON_LAYOUT_CLASS_SHORT .. ") not found")
        return
    end

    local btn_class = StaticFindObject(BUTTON_WRAPPER_CLASS_PATH)
    if not btn_class or not btn_class:IsValid() then
        print("[CyrodiilMP] add_button: button wrapper class not found at " .. BUTTON_WRAPPER_CLASS_PATH)
        return
    end

    local new_btn
    local construct_ok = pcall(function()
        new_btn = StaticConstructObject(btn_class, layout)
    end)

    if not construct_ok or not new_btn or not new_btn:IsValid() then
        print("[CyrodiilMP] add_button: StaticConstructObject failed")
        return
    end

    pcall(function() new_btn.ButtonText = FText("MULTIPLAYER") end)
    pcall(function() new_btn.LabelText = FText("MULTIPLAYER") end)
    pcall(function() new_btn.Text = FText("MULTIPLAYER") end)

    local tbs = FindAllOf("TextBlock")
    for _, tb in pairs(tbs or {}) do
        local tb_outer = safe_full_name(new_btn)
        if tb_outer ~= "" and string.find(safe_full_name(tb), tb_outer, 1, true) then
            pcall(function() tb:SetText(FText("MULTIPLAYER")) end)
        end
    end

    local add_ok = pcall(function()
        layout:AddChild(new_btn)
    end)

    if add_ok then
        print("[CyrodiilMP] MULTIPLAYER button added to " .. BUTTON_LAYOUT_CLASS_SHORT)
    else
        print("[CyrodiilMP] add_button: AddChild failed")
    end
end

local function should_connect_for_context(context_name)
    return string.find(context_name, "main_credits_wrapper") ~= nil
        or string.find(context_name, "cyrodiilmp_multiplayer") ~= nil
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

            if should_connect_for_context(context_name) then
                record_click_event(reason, context_name)
                connect_requested(reason .. " credits-filter", actual_context)
            elseif logNonCreditsClicks then
                record_click_event(reason, context_name)
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
    print("[CyrodiilMP] Hook " .. status .. ": " .. function_path .. " " .. detail)
end

local function write_hook_status()
    local lines = {
        "# CyrodiilMP Click Hook Status",
        "",
        "Hooks CommonUI button clicks; triggers connect flow for Credits/MULTIPLAYER slot.",
        ""
    }
    for _, hook in ipairs(registeredHooks) do
        table.insert(lines, "- " .. hook.status .. ": `" .. hook.path .. "` (" .. hook.detail .. ")")
    end
    write_lines("hook-status.md", lines)
end

print("[CyrodiilMP_ConnectButtonPrototype] Loaded.")
print("[CyrodiilMP_ConnectButtonPrototype] Server: " .. serverHost .. ":" .. serverPort)

write_lines("click-events.csv", { "Time,Reason,Context" })
write_lines("connect-events.csv", { "Time,Reason,Target,Context" })

register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", "CommonButtonBase HandleButtonClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:BP_OnClicked", "CommonButtonBase BP_OnClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonPressed", "CommonButtonBase HandleButtonPressed")

write_hook_status()

ExecuteWithDelay(20000, function()
    if enableAutoMenuProbe then
        print("[CyrodiilMP_ConnectButtonPrototype] Auto menu probe after 20 seconds.")
        run_menu_probe()
    end
end)

RegisterProcessConsoleExecPreHook(function(Context, Cmd, CommandParts, Ar, Executor)
    local command = tostring(Cmd):lower()
    if command == "cyro_connect" or command == "cyro_connect_server" then
        connect_requested("console-command", Context)
        return true
    end
    if command == "cyro_menu_probe" or command == "cyro_probe_menu" then
        run_menu_probe()
        return true
    end
    if command == "cyro_relabel" then
        relabel_credits_button()
        return true
    end
    if command == "cyro_add_button" then
        add_multiplayer_button()
        return true
    end
end)
