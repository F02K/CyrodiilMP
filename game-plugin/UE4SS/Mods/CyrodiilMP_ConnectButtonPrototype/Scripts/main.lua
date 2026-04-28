local serverHost = "127.0.0.1"
local serverPort = "27015"
local probeDirName = "CyrodiilMP_MenuProbe"
local bridgeExe = "CyrodiilMP/ClientBridge/CyrodiilMP.ClientBridge.exe"
local autoProbeRuns = 0
local registeredHooks = {}
local connectInProgress = false

-- Blueprint class paths confirmed from RuntimeInspector World.csv / menu-probe.csv
local BUTTON_WRAPPER_CLASS_PATH = "/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C"
local BUTTON_LAYOUT_CLASS_SHORT = "WBP_Modern_MainMenu_ButtonLayout_C"
-- World map name confirmed from RuntimeInspector World.csv (L_PersistentDungeon)
local WORLD_MAP_NAME = "L_PersistentDungeon"

-- ─── Utility ────────────────────────────────────────────────────────────────

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
        print("[CyrodiilMP] Could not write " .. file_name)
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

-- ─── Bridge result + world load (defined before connect_requested) ───────────

-- Read the bridge result JSON written by CyrodiilMP.ClientBridge.exe.
local function read_bridge_result(resultPath)
    local f = io.open(resultPath, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    local success = string.find(content, '"Success":true') ~= nil
    local player_id = tonumber(string.match(content, '"PlayerId":(%d+)'))
    return { success = success, player_id = player_id, raw = content }
end

-- After confirmed server-welcome, open the game world.
local function load_into_world(player_id)
    print("[CyrodiilMP] Server accepted. PlayerId=" .. tostring(player_id))
    local pc = FindFirstOf("PlayerController")
    if pc and pc:IsValid() then
        print("[CyrodiilMP] Opening level: " .. WORLD_MAP_NAME)
        local cmd_ok = pcall(function()
            pc:ConsoleCommand("open " .. WORLD_MAP_NAME, false)
        end)
        if not cmd_ok then
            print("[CyrodiilMP] ConsoleCommand failed. Map name: " .. WORLD_MAP_NAME)
        end
    else
        print("[CyrodiilMP] PlayerController not found; cannot trigger level load.")
    end
    connectInProgress = false
end

-- ─── Connect flow ────────────────────────────────────────────────────────────

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

    write_lines("connect-request.md", {
        "# CyrodiilMP Connect Request",
        "",
        "- Time: " .. timestamp,
        "- Reason: " .. reason,
        "- Target server: " .. serverHost .. ":" .. serverPort,
        "- Context: `" .. context_name .. "`",
    })

    append_line("connect-events.csv", table.concat({
        csv_escape(timestamp),
        csv_escape(reason),
        csv_escape(serverHost .. ":" .. serverPort),
        csv_escape(context_name)
    }, ","))

    local resultPath = probeDirName .. "/client-bridge-result.json"
    local bridge_args = table.concat({
        "--host", shell_quote(serverHost),
        "--port", shell_quote(serverPort),
        "--name", shell_quote("OblivionPlayer"),
        "--reason", shell_quote(reason),
        "--timeout-ms", "1800",
        "--out", shell_quote(resultPath)
    }, " ")

    -- Launch the bridge non-blocking so the game thread does not freeze.
    -- 'start "" /b' runs the exe in the background on Windows; control
    -- returns immediately, and we read the result file after a delay.
    local async_command = 'start "" /b ' .. shell_quote(bridgeExe) .. " " .. bridge_args
    print("[CyrodiilMP] Launching bridge (async): " .. async_command)
    os.execute(async_command)

    write_lines("client-bridge-launch.md", {
        "# CyrodiilMP Client Bridge Launch",
        "",
        "- Time: " .. os.date("%Y-%m-%dT%H:%M:%S"),
        "- Command: `" .. async_command .. "`",
        "- Result path: `" .. resultPath .. "`",
        "- Mode: async (result read after 2500 ms delay)",
    })

    -- Bridge timeout is 1800 ms; wait 2500 ms to be safe, then read result.
    ExecuteWithDelay(2500, function()
        local result = read_bridge_result(resultPath)
        if result == nil then
            print("[CyrodiilMP] Bridge result not found at: " .. resultPath)
            connectInProgress = false
        elseif result.success then
            load_into_world(result.player_id)
        else
            print("[CyrodiilMP] Bridge failed. Check " .. resultPath)
            connectInProgress = false
        end
    end)
end

-- ─── Button management ───────────────────────────────────────────────────────

-- Rename the Credits button label to MULTIPLAYER.
-- Uses FindAllOf("TextBlock") and filters by widget full-name path so we don't
-- need GetAllChildren() (which is unreliable in UE4SS Lua).
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
            else
                print("[CyrodiilMP] SetText failed on: " .. full_name)
            end
        end
    end
    if relabelled == 0 then
        print("[CyrodiilMP] relabel: no Credits TextBlock found (widget tree may not be ready)")
    end
end

-- Inject a new MULTIPLAYER button into the main menu layout panel.
-- Uses StaticConstructObject with the Blueprint class path from the runtime dump,
-- then calls AddChild on the layout panel.
-- Falls back gracefully with log messages if any step fails.
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

    -- Attempt to set the button label. Property name may vary; try common candidates.
    pcall(function() new_btn.ButtonText = FText("MULTIPLAYER") end)
    pcall(function() new_btn.LabelText  = FText("MULTIPLAYER") end)
    pcall(function() new_btn.Text       = FText("MULTIPLAYER") end)

    -- Also rename any TextBlock inside the new widget
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

-- ─── Menu probe (research helper, unchanged) ─────────────────────────────────

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

-- ─── Hook registration ───────────────────────────────────────────────────────

local function should_connect_for_context(context_name)
    -- Trigger on the Credits slot (which is relabelled to MULTIPLAYER)
    -- OR on our newly injected button (its name contains the class short name).
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
            if ok_context then actual_context = result end

            local context_name = safe_full_name(actual_context)
            print("[CyrodiilMP] CommonUI hook: " .. reason .. " / " .. context_name)
            append_line("click-events.csv", table.concat({
                csv_escape(os.date("%Y-%m-%dT%H:%M:%S")),
                csv_escape(reason),
                csv_escape(context_name)
            }, ","))

            if should_connect_for_context(context_name) then
                connect_requested(reason, actual_context)
            end
        end)
    end)

    local status = ok and "registered" or "failed"
    local detail = ok and ("pre=" .. safe_tostring(pre_id) .. " post=" .. safe_tostring(post_id)) or safe_tostring(pre_id)
    table.insert(registeredHooks, { status = status, path = function_path, detail = detail })
    print("[CyrodiilMP] Hook " .. status .. ": " .. function_path .. " " .. detail)
end

local function write_hook_status()
    local lines = {
        "# CyrodiilMP Click Hook Status", "",
        "Hooks CommonUI button clicks; triggers connect flow for Credits/MULTIPLAYER slot.", ""
    }
    for _, hook in ipairs(registeredHooks) do
        table.insert(lines, "- " .. hook.status .. ": `" .. hook.path .. "` (" .. hook.detail .. ")")
    end
    write_lines("hook-status.md", lines)
end

-- ─── Initialisation ──────────────────────────────────────────────────────────

print("[CyrodiilMP_ConnectButtonPrototype] Loaded.")
print("[CyrodiilMP_ConnectButtonPrototype] Server: " .. serverHost .. ":" .. serverPort)
print("[CyrodiilMP_ConnectButtonPrototype] World map: " .. WORLD_MAP_NAME)

write_lines("click-events.csv",   { "Time,Reason,Context" })
write_lines("connect-events.csv", { "Time,Reason,Target,Context" })

register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", "HandleButtonClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:BP_OnClicked",        "BP_OnClicked")
register_common_button_hook("/Script/CommonUI.CommonButtonBase:HandleButtonPressed", "HandleButtonPressed")

write_hook_status()

-- At 20 s the widget tree is stable enough to relabel and inject.
ExecuteWithDelay(20000, function()
    print("[CyrodiilMP] 20 s: running menu probe, relabel, and button injection.")
    run_menu_probe()
    relabel_credits_button()
    add_multiplayer_button()
end)

-- Retry at 45 s in case widgets weren't ready at 20 s.
ExecuteWithDelay(45000, function()
    print("[CyrodiilMP] 45 s: retry relabel and button injection.")
    run_menu_probe()
    relabel_credits_button()
    add_multiplayer_button()
end)

-- Final retry at 90 s.
ExecuteWithDelay(90000, function()
    print("[CyrodiilMP] 90 s: final retry relabel and button injection.")
    relabel_credits_button()
    add_multiplayer_button()
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
