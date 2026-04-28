#pragma once

// ─── CyrodiilMP Scripting Host — Public C ABI ────────────────────────────────
//
// This is the stable public surface that future scripting consumers can use.
// Because it is a plain C ABI (no C++ name mangling, no STL types in the
// interface), it can be consumed by:
//   • Another DLL (C/C++)
//   • A C# P/Invoke caller (future .NET CLR host inside the game process)
//   • A Lua binding (future sol2 wrapper)
//   • Any other language that can call a Windows DLL export
//
// Adding new exports never breaks existing callers (they just don't use them).
// Removing or changing existing exports is a breaking change — avoid it.

extern "C" {

// ── Event subscription ────────────────────────────────────────────────────────

// Callback signature: both strings are UTF-8, null-terminated.
// event_name  – one of the well-known names listed below.
// payload_json – a compact JSON object whose keys depend on the event.
typedef void (*CyrodiilEventCallback)(const char* event_name,
                                      const char* payload_json);

// Register a handler for a named event.  Multiple handlers per event are
// supported.  Handlers are called synchronously on the game thread.
// event_name  – exact string match (e.g. "connect.succeeded").
//               Pass "*" to receive every event.
// callback    – must be non-null; may be called from the game thread only.
__declspec(dllexport)
void CyrodiilMP_RegisterEventHandler(const char* event_name,
                                     CyrodiilEventCallback callback);

// Remove all registrations for a specific callback pointer.
__declspec(dllexport)
void CyrodiilMP_UnregisterEventHandler(CyrodiilEventCallback callback);

// ── Event dispatch ────────────────────────────────────────────────────────────

// Fire an event from external code.  The GameHost will also call this
// internally for built-in events.  Handlers execute before this returns.
// event_name   – caller-defined or one of the well-known names.
// payload_json – must be valid JSON or an empty string "{}".
__declspec(dllexport)
void CyrodiilMP_FireEvent(const char* event_name, const char* payload_json);

// ── State queries ─────────────────────────────────────────────────────────────

// Returns the local player's server-assigned ID, or 0 if not connected.
__declspec(dllexport)
int CyrodiilMP_GetPlayerId();

// Returns true if a server-welcome has been received and the session is live.
__declspec(dllexport)
bool CyrodiilMP_IsConnected();

} // extern "C"

// ── Well-known event names ────────────────────────────────────────────────────
// Keep these in sync with ScriptingHost.cpp.
//
//  "connect.requested"   {}
//  "connect.succeeded"   {"player_id": <int>}
//  "connect.failed"      {"reason": "<string>"}
//  "level.loading"       {"map": "<string>"}
//
// Future (not yet fired):
//  "player.joined"       {"player_id": <int>, "name": "<string>"}
//  "player.left"         {"player_id": <int>}
//  "transform.received"  {"player_id": <int>, "x":.., "y":.., "z":.., "yaw":..}
