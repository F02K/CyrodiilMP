#include "../include/ScriptingHost.hpp"

#include <DynamicOutput/DynamicOutput.hpp>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

// ─── Internal registry ────────────────────────────────────────────────────────

namespace {

struct HandlerEntry {
    std::string            eventPattern; // exact name, or "*" for all
    CyrodiilEventCallback  callback;
};

static std::mutex                 s_mutex;
static std::vector<HandlerEntry>  s_handlers;
static std::atomic<int>           s_playerId{0};
static std::atomic<bool>          s_connected{false};

} // anonymous namespace

// ─── C ABI exports ────────────────────────────────────────────────────────────

extern "C" {

void CyrodiilMP_RegisterEventHandler(const char* event_name,
                                     CyrodiilEventCallback callback)
{
    if (!event_name || !callback) return;
    std::lock_guard lock(s_mutex);
    s_handlers.push_back({event_name, callback});
}

void CyrodiilMP_UnregisterEventHandler(CyrodiilEventCallback callback)
{
    if (!callback) return;
    std::lock_guard lock(s_mutex);
    s_handlers.erase(
        std::remove_if(s_handlers.begin(), s_handlers.end(),
            [callback](const HandlerEntry& e) { return e.callback == callback; }),
        s_handlers.end());
}

void CyrodiilMP_FireEvent(const char* event_name, const char* payload_json)
{
    if (!event_name) return;
    const char* safe_payload = payload_json ? payload_json : "{}";

    // Update internal state for well-known events.
    if (std::string_view(event_name) == "connect.succeeded")
    {
        s_connected = true;
        // Extract player_id from payload — simple scan, not a full parser.
        std::string p = safe_payload;
        auto pos = p.find("\"player_id\":");
        if (pos != std::string::npos)
        {
            try { s_playerId = std::stoi(p.substr(pos + 12)); } catch (...) {}
        }
    }
    else if (std::string_view(event_name) == "connect.failed")
    {
        s_connected = false;
        s_playerId  = 0;
    }

    // Collect matching handlers (copy to avoid re-entrant modification).
    std::vector<CyrodiilEventCallback> toCall;
    {
        std::lock_guard lock(s_mutex);
        for (auto& entry : s_handlers)
        {
            if (entry.eventPattern == "*" || entry.eventPattern == event_name)
                toCall.push_back(entry.callback);
        }
    }

    for (auto cb : toCall)
    {
        try { cb(event_name, safe_payload); }
        catch (...) {
            RC::Output::send<RC::LogLevel::Error>(
                STR("[CyrodiilMP.GameHost] ScriptingHost: handler threw an exception\n"));
        }
    }
}

int CyrodiilMP_GetPlayerId()
{
    return s_playerId.load(std::memory_order_relaxed);
}

bool CyrodiilMP_IsConnected()
{
    return s_connected.load(std::memory_order_relaxed);
}

} // extern "C"
