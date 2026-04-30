local UEHelpers = require("UEHelpers")

local DEFAULT_HOST = "127.0.0.1"
local DEFAULT_PORT = 27016
local DEFAULT_NAME = "Player"
local TICK_MS = 100

local state = {
    running = false,
    tick = 0,
    draw_failed = false,
    remote_players = {}
}

local function log(message)
    print("[CyrodiilMP_MultiplayerPrototype] " .. tostring(message) .. "\n")
end

local function split_command(command)
    local parts = {}
    for token in tostring(command):gmatch("%S+") do
        table.insert(parts, token)
    end
    return parts
end

local function is_valid(object)
    local ok, result = pcall(function()
        return object ~= nil and object:IsValid()
    end)
    return ok and result
end

local function get_number(value, fallback)
    if type(value) == "number" then
        return value
    end

    local ok, result = pcall(function()
        return value:get()
    end)
    if ok and type(result) == "number" then
        return result
    end

    return fallback or 0.0
end

local function vector_component(vector, upper, lower)
    if vector == nil then
        return 0.0
    end
    return get_number(vector[upper] or vector[lower], 0.0)
end

local function rotation_yaw(rotation)
    if rotation == nil then
        return 0.0
    end
    return get_number(rotation.Yaw or rotation.yaw, 0.0)
end

local function get_local_transform()
    local pawn = UEHelpers.GetPlayer()
    if not is_valid(pawn) then
        return nil, "local pawn not valid"
    end

    local ok_location, location = pcall(function()
        return pawn:K2_GetActorLocation()
    end)
    if not ok_location then
        return nil, "K2_GetActorLocation failed"
    end

    local ok_rotation, rotation = pcall(function()
        return pawn:K2_GetActorRotation()
    end)
    if not ok_rotation then
        rotation = nil
    end

    state.tick = state.tick + 1
    return {
        tick = state.tick,
        x = vector_component(location, "X", "x"),
        y = vector_component(location, "Y", "y"),
        z = vector_component(location, "Z", "z"),
        yaw = rotation_yaw(rotation)
    }
end

local function draw_remote_proxy(remote)
    if state.draw_failed then
        return
    end

    local ok = pcall(function()
        local system = UEHelpers.GetKismetSystemLibrary()
        local world = UEHelpers.GetWorld()
        if not is_valid(system) or not is_valid(world) then
            error("debug draw unavailable")
        end

        local position = {
            X = remote.x,
            Y = remote.y,
            Z = remote.z + 120.0
        }
        local color = {
            R = 0.0,
            G = 0.8,
            B = 1.0,
            A = 1.0
        }

        system:DrawDebugSphere(world, position, 45.0, 12, color, 0.25, 3.0)
        if system.DrawDebugString then
            system:DrawDebugString(world, position, "P" .. tostring(remote.player), nil, color, 0.25, true, 1.0)
        end
    end)

    if not ok then
        state.draw_failed = true
        log("debug draw failed; remote transforms will still be logged")
    end
end

local function handle_event(event)
    if event.type == "server-welcome" then
        log("connected as player " .. tostring(event.player))
        return
    end

    if event.type == "remote-transform" then
        state.remote_players[event.player] = {
            player = event.player,
            name = event.name,
            tick = event.tick,
            x = event.x,
            y = event.y,
            z = event.z,
            yaw = event.yaw,
            last_seen = os.clock()
        }
        draw_remote_proxy(state.remote_players[event.player])
        return
    end

    if event.type == "player-left" then
        state.remote_players[event.player] = nil
        log("player left: " .. tostring(event.player) .. " reason=" .. tostring(event.reason))
    end
end

local function pump()
    if not state.running then
        return
    end

    if CyrodiilMP == nil then
        log("CyrodiilMP C++ API is not registered")
        state.running = false
        return
    end

    local transform, transform_error = get_local_transform()
    if transform ~= nil then
        CyrodiilMP.SendLocalTransform(transform)
    elseif state.tick % 20 == 0 then
        log(transform_error)
    end

    local events = CyrodiilMP.PollEvents()
    for _, event in ipairs(events or {}) do
        handle_event(event)
    end

    ExecuteWithDelay(TICK_MS, pump)
end

local function connect(host, port, name)
    if CyrodiilMP == nil then
        log("CyrodiilMP C++ API is not registered. Build/install the extended RE-UE4SS runtime first.")
        return
    end

    local ok, status = CyrodiilMP.Connect(host or DEFAULT_HOST, port or DEFAULT_PORT, name or DEFAULT_NAME)
    state.running = ok
    if ok then
        log("connect requested host=" .. tostring(host or DEFAULT_HOST) .. " port=" .. tostring(port or DEFAULT_PORT))
        ExecuteWithDelay(TICK_MS, pump)
    else
        log("connect failed: " .. tostring(status and status.last_error or "unknown"))
    end
end

local function disconnect()
    state.running = false
    state.remote_players = {}
    if CyrodiilMP ~= nil then
        CyrodiilMP.Disconnect()
    end
    log("disconnected")
end

local function status()
    if CyrodiilMP == nil then
        log("CyrodiilMP C++ API is not registered")
        return
    end

    local s = CyrodiilMP.GetStatus()
    log(string.format(
        "socket_open=%s connected=%s player_id=%s host=%s port=%s error=%s",
        tostring(s.socket_open),
        tostring(s.connected),
        tostring(s.player_id),
        tostring(s.host),
        tostring(s.port),
        tostring(s.last_error)))
end

RegisterProcessConsoleExecPreHook(function(Context, Cmd, CommandParts, Ar, Executor)
    local parts = split_command(Cmd)
    local command = tostring(parts[1] or ""):lower()

    if command == "cyro_mp_connect" then
        connect(parts[2] or DEFAULT_HOST, tonumber(parts[3]) or DEFAULT_PORT, parts[4] or DEFAULT_NAME)
        return true
    end

    if command == "cyro_mp_disconnect" then
        disconnect()
        return true
    end

    if command == "cyro_mp_status" then
        status()
        return true
    end
end)

log("loaded. Use cyro_mp_connect [host] [port] [name].")
