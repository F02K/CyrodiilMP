#include "BridgeLauncher.hpp"
#include "../include/ScriptingHost.hpp"

#include <DynamicOutput/DynamicOutput.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>

#include <atomic>
#include <mutex>
#include <queue>
#include <string>
#include <thread>

// Windows API for CreateProcess and file I/O.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace CyrodiilMP::BridgeLauncher {

// ── Config ────────────────────────────────────────────────────────────────────

// Relative to the game's Win64/ working directory (same as Lua mod convention).
static constexpr wchar_t BRIDGE_EXE[] =
    L"CyrodiilMP\\ClientBridge\\CyrodiilMP.ClientBridge.exe";

static constexpr char SERVER_HOST[] = "127.0.0.1";
static constexpr int  SERVER_PORT   = 27015;

// Result file written by the bridge, relative to Win64/.
static constexpr wchar_t RESULT_PATH[] =
    L"CyrodiilMP_MenuProbe\\client-bridge-result.json";

// Map to open after a successful connect (confirmed from RuntimeInspector).
static constexpr char WORLD_MAP[] = "L_PersistentDungeon";

// ── Internal result queue ─────────────────────────────────────────────────────

struct BridgeResult {
    bool        success;
    int         playerId;   // 0 on failure
    std::string errorMsg;   // empty on success
};

static std::mutex              s_queueMutex;
static std::queue<BridgeResult> s_resultQueue;
static std::atomic<bool>       s_launchInFlight{false};

static void Enqueue(BridgeResult result)
{
    std::lock_guard lock(s_queueMutex);
    s_resultQueue.push(std::move(result));
}

// ── JSON helpers ──────────────────────────────────────────────────────────────

// Minimal JSON pattern match — avoids a full JSON parser dependency.
static bool JsonBool(const std::string& json, const char* key)
{
    auto needle = std::string("\"") + key + "\":true";
    return json.find(needle) != std::string::npos;
}

static int JsonInt(const std::string& json, const char* key)
{
    auto prefix = std::string("\"") + key + "\":";
    auto pos = json.find(prefix);
    if (pos == std::string::npos) return 0;
    pos += prefix.size();
    int value = 0;
    try { value = std::stoi(json.substr(pos)); } catch (...) {}
    return value;
}

// ── Bridge process runner (runs on background thread) ────────────────────────

static void RunBridge()
{
    // Build the full command line.
    wchar_t cmdLine[2048] = {};
    swprintf_s(cmdLine,
        L"\"%s\" --host \"%S\" --port %d --name OblivionPlayer"
        L" --reason multiplayer-button --timeout-ms 1800 --out \"%s\"",
        BRIDGE_EXE, SERVER_HOST, SERVER_PORT, RESULT_PATH);

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};

    BOOL ok = CreateProcessW(
        nullptr,          // lpApplicationName (use cmdLine)
        cmdLine,
        nullptr,          // process security attrs
        nullptr,          // thread security attrs
        FALSE,            // bInheritHandles
        CREATE_NO_WINDOW, // no console window
        nullptr,          // inherit environment
        nullptr,          // inherit cwd (Win64/)
        &si,
        &pi);

    if (!ok)
    {
        DWORD err = GetLastError();
        RC::Output::send<RC::LogLevel::Error>(
            STR("[CyrodiilMP.GameHost] BridgeLauncher: CreateProcess failed (error {})\n"),
            err);
        Enqueue({false, 0, "CreateProcess failed: error " + std::to_string(err)});
        s_launchInFlight = false;
        return;
    }

    // Wait for the bridge to finish (it will exit after receiving server-welcome
    // or after its 1800 ms timeout).
    WaitForSingleObject(pi.hProcess, 4000 /*ms safety ceiling*/);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // Read the result JSON written by the bridge.
    HANDLE hFile = CreateFileW(RESULT_PATH, GENERIC_READ, FILE_SHARE_READ,
                               nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE)
    {
        RC::Output::send<RC::LogLevel::Error>(
            STR("[CyrodiilMP.GameHost] BridgeLauncher: result file not found\n"));
        Enqueue({false, 0, "result file not found"});
        s_launchInFlight = false;
        return;
    }

    DWORD fileSize = GetFileSize(hFile, nullptr);
    std::string json(fileSize, '\0');
    DWORD bytesRead = 0;
    ReadFile(hFile, json.data(), fileSize, &bytesRead, nullptr);
    CloseHandle(hFile);

    bool success  = JsonBool(json, "Success");
    int  playerId = JsonInt(json,  "PlayerId");

    Enqueue({success, playerId, success ? "" : json});
    s_launchInFlight = false;
}

// ── Public API ────────────────────────────────────────────────────────────────

void LaunchAsync()
{
    bool expected = false;
    if (!s_launchInFlight.compare_exchange_strong(expected, true))
    {
        RC::Output::send<RC::LogLevel::Normal>(
            STR("[CyrodiilMP.GameHost] BridgeLauncher: launch already in flight, ignoring\n"));
        return;
    }

    RC::Output::send<RC::LogLevel::Normal>(
        STR("[CyrodiilMP.GameHost] BridgeLauncher: launching bridge on background thread\n"));

    std::thread(RunBridge).detach();
}

void DrainResultQueue()
{
    std::queue<BridgeResult> local;
    {
        std::lock_guard lock(s_queueMutex);
        std::swap(local, s_resultQueue);
    }

    while (!local.empty())
    {
        auto result = std::move(local.front());
        local.pop();

        if (result.success)
        {
            RC::Output::send<RC::LogLevel::Normal>(
                STR("[CyrodiilMP.GameHost] Bridge succeeded. PlayerId={}\n"),
                result.playerId);

            // Fire scripting event.
            auto payload = "{\"player_id\":" + std::to_string(result.playerId) + "}";
            CyrodiilMP_FireEvent("connect.succeeded", payload.c_str());

            // Open the game world on the main thread (safe here — we are in on_update).
            auto* pc = RC::Unreal::UObjectGlobals::FindFirstOf(STR("PlayerController"));
            if (pc)
            {
                auto* consoleFn = pc->GetFunctionByName(STR("ConsoleCommand"));
                if (consoleFn)
                {
                    struct ConsoleCommandParams {
                        RC::Unreal::FString Command;
                        bool                bWriteToLog{false};
                        RC::Unreal::FString ReturnValue;
                    } params;
                    params.Command = RC::Unreal::FString(STR("open ") + std::wstring(
                        WORLD_MAP, WORLD_MAP + strlen(WORLD_MAP)));
                    pc->ProcessEvent(consoleFn, &params);

                    CyrodiilMP_FireEvent("level.loading",
                        ("{\"map\":\"" + std::string(WORLD_MAP) + "\"}").c_str());
                }
            }
            else
            {
                RC::Output::send<RC::LogLevel::Warning>(
                    STR("[CyrodiilMP.GameHost] PlayerController not found; cannot open level\n"));
            }
        }
        else
        {
            RC::Output::send<RC::LogLevel::Error>(
                STR("[CyrodiilMP.GameHost] Bridge failed\n"));
            auto payload = "{\"reason\":\"bridge-failed\"}";
            CyrodiilMP_FireEvent("connect.failed", payload);
        }
    }
}

} // namespace CyrodiilMP::BridgeLauncher
