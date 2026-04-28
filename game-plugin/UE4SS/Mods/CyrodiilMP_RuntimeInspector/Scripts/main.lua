local autoDumpDelaysMs = { 120000 }
local dumpDirName = "CyrodiilMP_RuntimeDumps"

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
    local file = io.open(dumpDirName .. "/" .. file_name, "w")
    if not file then
        print("[CyrodiilMP_RuntimeInspector] Could not write " .. file_name)
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()
end

local function csv_escape(value)
    value = safe_tostring(value)
    value = value:gsub('"', '""')
    return '"' .. value .. '"'
end

local function collect_class(short_class_name, max_count)
    local rows = {}
    table.insert(rows, "ClassQuery,FullName,ClassName")

    local ok, objects = pcall(function()
        return FindAllOf(short_class_name)
    end)

    if not ok or objects == nil then
        return rows, 0
    end

    local count = 0
    for _, object in pairs(objects) do
        count = count + 1
        if count <= max_count then
            table.insert(rows, table.concat({
                csv_escape(short_class_name),
                csv_escape(safe_full_name(object)),
                csv_escape(safe_class_name(object))
            }, ","))
        end
    end

    return rows, count
end

local function dump_functions_for_class(class_name)
    local lines = {}
    table.insert(lines, "Class,Function")

    local class = StaticFindObject(class_name)
    if class == nil or not class:IsValid() then
        table.insert(lines, csv_escape(class_name) .. "," .. csv_escape("<not found>"))
        return lines
    end

    local ok = pcall(function()
        class:ForEachFunction(function(function_object)
            table.insert(lines, csv_escape(class_name) .. "," .. csv_escape(safe_full_name(function_object)))
        end)
    end)

    if not ok then
        table.insert(lines, csv_escape(class_name) .. "," .. csv_escape("<ForEachFunction failed>"))
    end

    return lines
end

local function dump_runtime()
    local summary = {}
    table.insert(summary, "# CyrodiilMP Runtime Inspector")
    table.insert(summary, "")
    table.insert(summary, "Dump created from UE4SS while Oblivion Remastered was running.")
    table.insert(summary, "")

    local queries = {
        { name = "UserWidget", max = 5000 },
        { name = "Widget", max = 12000 },
        { name = "Button", max = 1000 },
        { name = "TextBlock", max = 5000 },
        { name = "PanelWidget", max = 2000 },
        { name = "WidgetTree", max = 3000 },
        { name = "WidgetBlueprintGeneratedClass", max = 2000 },
        { name = "CommonButtonBase", max = 1000 },
        { name = "CommonButtonInternalBase", max = 1000 },
        { name = "PlayerController", max = 100 },
        { name = "HUD", max = 100 },
        { name = "Pawn", max = 500 },
        { name = "Character", max = 500 },
        { name = "GameInstance", max = 100 },
        { name = "GameViewportClient", max = 100 },
        { name = "World", max = 100 }
    }

    for _, query in ipairs(queries) do
        local rows, count = collect_class(query.name, query.max)
        write_lines(query.name .. ".csv", rows)
        table.insert(summary, "- `" .. query.name .. "`: " .. tostring(count) .. " (captured " .. tostring(math.min(count, query.max)) .. ")")
    end

    write_lines("PlayerController-functions.csv", dump_functions_for_class("/Script/Engine.PlayerController"))
    write_lines("UserWidget-functions.csv", dump_functions_for_class("/Script/UMG.UserWidget"))
    write_lines("Button-functions.csv", dump_functions_for_class("/Script/UMG.Button"))
    write_lines("CommonButtonBase-functions.csv", dump_functions_for_class("/Script/CommonUI.CommonButtonBase"))
    write_lines("CommonButtonInternalBase-functions.csv", dump_functions_for_class("/Script/CommonUI.CommonButtonInternalBase"))
    write_lines("PanelWidget-functions.csv", dump_functions_for_class("/Script/UMG.PanelWidget"))
    write_lines("WidgetTree-functions.csv", dump_functions_for_class("/Script/UMG.WidgetTree"))
    write_lines("WBP_LegacyMenu_Main-functions.csv", dump_functions_for_class("/Game/UI/Legacy/MenuLayer/WBP_LegacyMenu_Main.WBP_LegacyMenu_Main_C"))
    write_lines("WBP_Modern_MainMenu_ButtonLayout-functions.csv", dump_functions_for_class("/Game/UI/Modern/MenuLayer/MainMenu/WBP_Modern_MainMenu_ButtonLayout.WBP_Modern_MainMenu_ButtonLayout_C"))
    write_lines("WBP_MainMenu_Button_Wrapper-functions.csv", dump_functions_for_class("/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button_Wrapper.WBP_MainMenu_Button_Wrapper_C"))
    write_lines("WBP_MainMenu_Button-functions.csv", dump_functions_for_class("/Game/UI/Modern/Prefabs/Buttons/WBP_MainMenu_Button.WBP_MainMenu_Button_C"))

    write_lines("summary.md", summary)
    print("[CyrodiilMP_RuntimeInspector] Dump complete in " .. dumpDirName)
end

local function run_scheduled_dump(label)
    print("[CyrodiilMP_RuntimeInspector] Running " .. label .. " runtime dump.")
    dump_runtime()
end

print("[CyrodiilMP_RuntimeInspector] Loaded. Runtime dumps run automatically; console commands are optional.")

for _, delayMs in ipairs(autoDumpDelaysMs) do
    ExecuteWithDelay(delayMs, function()
        run_scheduled_dump(tostring(math.floor(delayMs / 1000)) .. " second")
    end)
end

RegisterProcessConsoleExecPreHook(function(Context, Cmd, CommandParts, Ar, Executor)
    local command = safe_tostring(Cmd):lower()
    if command == "cyro_dump_runtime" or command == "cyro_dump_ui" then
        print("[CyrodiilMP_RuntimeInspector] Console command received: " .. command)
        dump_runtime()
        return true
    end
end)
