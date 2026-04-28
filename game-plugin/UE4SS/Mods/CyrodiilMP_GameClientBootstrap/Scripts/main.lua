local commandDir = "CyrodiilMP\\GameClient"
local gameClientDll = ".\\CyrodiilMP\\GameClient\\CyrodiilMP.GameClient.dll"
local statusFile = commandDir .. "\\bootstrap-status.txt"

local function ensure_command_dir()
    os.execute('cmd /c if not exist "' .. commandDir .. '" mkdir "' .. commandDir .. '"')
end

local function safe_tostring(value)
    local ok, result = pcall(function()
        if value == nil then return "" end
        return tostring(value)
    end)
    if ok then return result end
    return "<error>"
end

local function sanitize_line(value)
    value = safe_tostring(value)
    value = value:gsub("\r", " ")
    value = value:gsub("\n", " ")
    return value
end

local function write_status(message)
    ensure_command_dir()
    local file = io.open(statusFile, "w")
    if not file then
        print("[CyrodiilMP] Could not write " .. statusFile)
        return
    end

    file:write("loaded=1\n")
    file:write("message=" .. sanitize_line(message) .. "\n")
    file:close()
end

print("[CyrodiilMP_GameClientBootstrap] Loading native GameClient.")
ensure_command_dir()
write_status("loading native GameClient")

local loader, load_error = package.loadlib(gameClientDll, "luaopen_CyrodiilMP_GameClient")
if not loader then
    local message = "native load failed: " .. sanitize_line(load_error)
    print("[CyrodiilMP] " .. message)
    write_status(message)
    return
end

local ok, result = pcall(loader)
if not ok then
    local message = "native bootstrap failed: " .. sanitize_line(result)
    print("[CyrodiilMP] " .. message)
    write_status(message)
    return
end

print("[CyrodiilMP] Native GameClient loaded.")
write_status("native GameClient loaded")
