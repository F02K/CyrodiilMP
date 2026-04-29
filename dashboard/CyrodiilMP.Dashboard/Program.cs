using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
using System.Text.Json;

var root = FindProjectRoot();
var dashboardRoot = Path.Combine(root, "dashboard", "CyrodiilMP.Dashboard");
var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = dashboardRoot,
    WebRootPath = Path.Combine(dashboardRoot, "wwwroot")
});
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.WebHost.UseUrls(Environment.GetEnvironmentVariable("CYRODIILMP_DASHBOARD_URL") ?? "http://127.0.0.1:5088");

var app = builder.Build();
var jobState = new DashboardJobState();
var serverState = new DashboardServerState();
var serverScriptPath = Path.Combine(root, "scripts", "run-server.ps1");

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/api/meta", () => Results.Json(new
{
    appName = "CyrodiilMP Dashboard",
    projectRoot = root,
    dashboardRoot,
    gamePathFile = Path.Combine(root, "game-path.txt"),
    serverScriptPath
}));

app.MapGet("/api/state", () =>
{
    return Results.Json(BuildDashboardState(root, jobState, serverState, serverScriptPath));
});

app.MapGet("/api/settings/game-path", () =>
{
    var filePath = Path.Combine(root, "game-path.txt");
    return Results.Json(new
    {
        filePath,
        exists = File.Exists(filePath),
        gamePath = ReadGamePath(root)
    });
});

app.MapPut("/api/settings/game-path", (GamePathUpdateRequest request) =>
{
    var savedPath = WriteGamePath(root, request.GamePath);
    var filePath = Path.Combine(root, "game-path.txt");
    return Results.Json(new
    {
        filePath,
        exists = File.Exists(filePath),
        gamePath = savedPath
    });
});

app.MapGet("/api/jobs/current", () => Results.Json(jobState.Snapshot()));

app.MapPost("/api/jobs/cancel", () =>
{
    var result = jobState.CancelActiveJob();
    return result.Cancelled
        ? Results.Json(result.Snapshot)
        : Results.BadRequest(new { error = result.Reason, snapshot = result.Snapshot });
});

app.MapGet("/api/server", () => Results.Json(serverState.Snapshot(serverScriptPath)));

app.MapPost("/api/server/start", (ServerStartRequest request) =>
{
    var result = serverState.Start(root, serverScriptPath, request.Port ?? CyrodiilProtocol.DefaultPort);
    return result.Started
        ? Results.Accepted("/api/server", result.Snapshot)
        : Results.BadRequest(new { error = result.Reason, snapshot = result.Snapshot });
});

app.MapPost("/api/server/stop", () =>
{
    var result = serverState.Stop(serverScriptPath);
    return result.Stopped
        ? Results.Json(result.Snapshot)
        : Results.BadRequest(new { error = result.Reason, snapshot = result.Snapshot });
});

app.MapPost("/api/server/force-stop", () =>
{
    var result = serverState.ForceStop(serverScriptPath);
    return result.Stopped
        ? Results.Json(result.Snapshot)
        : Results.BadRequest(new { error = result.Reason, snapshot = result.Snapshot });
});

app.MapPost("/api/actions/install-ue4ss-mods", (GamePathRequest request) =>
{
    return StartDashboardJob(
        root,
        jobState,
        "Install UE4SS research helpers",
        Path.Combine(root, "scripts", "install-cyrodiilmp-ue4ss-mods.ps1"),
        BuildNamedArgs(
            ("-GamePath", request.GamePath)));
});

app.MapPost("/api/actions/full-research", (GamePathRequest request) =>
{
    return StartDashboardJob(
        root,
        jobState,
        "Full research",
        Path.Combine(root, "scripts", "full-research.ps1"),
        BuildNamedArgs(
            ("-GamePath", request.GamePath)));
});

app.MapPost("/api/actions/quick-scan", (GamePathRequest request) =>
{
    return StartDashboardJob(
        root,
        jobState,
        "Quick scan",
        Path.Combine(root, "scripts", "quick-scan.ps1"),
        BuildNamedArgs(
            ("-GamePath", request.GamePath)));
});

app.MapPost("/api/actions/new-research-run", (NameRequest request) =>
{
    return StartDashboardJob(
        root,
        jobState,
        "New research run",
        Path.Combine(root, "scripts", "new-research-run.ps1"),
        BuildNamedArgs(
            ("-Name", string.IsNullOrWhiteSpace(request.Name) ? "manual" : request.Name)));
});

app.MapPost("/api/actions/collect-runtime-dumps", (NamedGamePathRequest request) =>
{
    return StartDashboardJob(
        root,
        jobState,
        "Collect runtime dumps",
        Path.Combine(root, "scripts", "collect-runtime-dumps.ps1"),
        BuildNamedArgs(
            ("-GamePath", request.GamePath),
            ("-Name", string.IsNullOrWhiteSpace(request.Name) ? "runtime" : request.Name)));
});

app.MapPost("/api/actions/analyze-runtime-dump", (AnalyzeDumpRequest request) =>
{
    if (string.IsNullOrWhiteSpace(request.DumpId))
    {
        return Results.BadRequest(new { error = "dumpId is required." });
    }

    var dumpPath = GetRuntimeDumpPath(root, request.DumpId);
    if (dumpPath is null)
    {
        return Results.NotFound(new { error = "Runtime dump not found." });
    }

    return StartDashboardJob(
        root,
        jobState,
        $"Analyze runtime dump {request.DumpId}",
        Path.Combine(root, "scripts", "analyze-runtime-dump.ps1"),
        BuildNamedArgs(
            ("-DumpPath", dumpPath)));
});

app.MapPost("/api/actions/client-bridge", (ClientBridgeRequest request) =>
{
    var hostName = string.IsNullOrWhiteSpace(request.HostName) ? CyrodiilProtocol.DefaultHost : request.HostName.Trim();
    var port = request.Port ?? CyrodiilProtocol.DefaultPort;
    var name = string.IsNullOrWhiteSpace(request.Name) ? "DashboardBridge" : request.Name.Trim();
    var reason = string.IsNullOrWhiteSpace(request.Reason) ? "dashboard-smoke" : request.Reason.Trim();
    var timeoutMs = request.TimeoutMs is > 0 ? request.TimeoutMs.Value : 1800;

    return StartDashboardJob(
        root,
        jobState,
        "Client bridge smoke test",
        Path.Combine(root, "scripts", "run-client-bridge.ps1"),
        BuildNamedArgs(
            ("-HostName", hostName),
            ("-Port", port.ToString()),
            ("-Name", name),
            ("-Reason", reason),
            ("-TimeoutMs", timeoutMs.ToString())));
});

app.MapGet("/api/runs/{runId}", (string runId) =>
{
    var runPath = GetRunPath(root, runId);
    if (runPath is null)
    {
        return Results.NotFound(new { error = "Research run not found." });
    }

    var files = Directory.EnumerateFiles(runPath)
        .Select(path => new FileInfo(path))
        .OrderBy(file => file.Name)
        .Select(file => new
        {
            name = file.Name,
            sizeBytes = file.Length,
            lastWriteTime = file.LastWriteTime
        })
        .ToArray();

    var reportPath = Path.Combine(runPath, "report.md");
    var summaryPath = Path.Combine(runPath, "summary.json");

    object? summary = null;
    if (File.Exists(summaryPath))
    {
        summary = JsonSerializer.Deserialize<object>(File.ReadAllText(summaryPath));
    }

    return Results.Json(new
    {
        id = runId,
        path = runPath,
        preferredFile = File.Exists(reportPath) ? "report.md" : files.FirstOrDefault()?.name ?? "",
        summary,
        files
    });
});

app.MapGet("/api/runs/{runId}/files/{fileName}", (string runId, string fileName) =>
{
    var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "report.md",
        "summary.json",
        "packages.csv",
        "legacy-data.csv",
        "executables-and-dlls.csv",
        "ini-summary.csv",
        "largest-files.csv",
        "layout.csv",
        "steam-manifests.csv"
    };

    if (!allowed.Contains(fileName))
    {
        return Results.BadRequest(new { error = "File is not exposed by the dashboard." });
    }

    var runPath = GetRunPath(root, runId);
    if (runPath is null)
    {
        return Results.NotFound(new { error = "Research run not found." });
    }

    var filePath = Path.Combine(runPath, fileName);
    return ReadTextFileResult(filePath);
});

app.MapGet("/api/runtime-dumps/{dumpId}", (string dumpId) =>
{
    var dumpPath = GetRuntimeDumpPath(root, dumpId);
    if (dumpPath is null)
    {
        return Results.NotFound(new { error = "Runtime dump not found." });
    }

    var files = Directory.EnumerateFiles(dumpPath)
        .Select(path => new FileInfo(path))
        .Where(file => IsDashboardRuntimeFile(file.Name))
        .OrderBy(file => file.Name)
        .Select(file => new
        {
            name = file.Name,
            sizeBytes = file.Length,
            lastWriteTime = file.LastWriteTime
        })
        .ToArray();

    var preferredFile = File.Exists(Path.Combine(dumpPath, "menu-analysis.md"))
        ? "menu-analysis.md"
        : File.Exists(Path.Combine(dumpPath, "summary.md"))
            ? "summary.md"
            : files.FirstOrDefault()?.name ?? "";

    return Results.Json(new
    {
        id = dumpId,
        path = dumpPath,
        preferredFile,
        files
    });
});

app.MapGet("/api/runtime-dumps/{dumpId}/files/{fileName}", (string dumpId, string fileName) =>
{
    if (!IsSafeFileName(fileName) || !IsDashboardRuntimeFile(fileName))
    {
        return Results.BadRequest(new { error = "File is not exposed by the dashboard." });
    }

    var dumpPath = GetRuntimeDumpPath(root, dumpId);
    if (dumpPath is null)
    {
        return Results.NotFound(new { error = "Runtime dump not found." });
    }

    var filePath = Path.Combine(dumpPath, fileName);
    return ReadTextFileResult(filePath);
});

app.MapGet("/api/note-runs/{runId}", (string runId) =>
{
    var runPath = GetNoteRunPath(root, runId);
    if (runPath is null)
    {
        return Results.NotFound(new { error = "Research notes run not found." });
    }

    var files = Directory.EnumerateFiles(runPath)
        .Select(path => new FileInfo(path))
        .Where(file => IsDashboardTextArtifact(file.Name))
        .OrderBy(file => file.Name)
        .Select(file => new
        {
            name = file.Name,
            sizeBytes = file.Length,
            lastWriteTime = file.LastWriteTime
        })
        .ToArray();

    var preferredFile = File.Exists(Path.Combine(runPath, "notes.md"))
        ? "notes.md"
        : File.Exists(Path.Combine(runPath, "README.md"))
            ? "README.md"
            : files.FirstOrDefault()?.name ?? "";

    return Results.Json(new
    {
        id = runId,
        path = runPath,
        preferredFile,
        files
    });
});

app.MapGet("/api/note-runs/{runId}/files/{fileName}", (string runId, string fileName) =>
{
    if (!IsSafeFileName(fileName) || !IsDashboardTextArtifact(fileName))
    {
        return Results.BadRequest(new { error = "File is not exposed by the dashboard." });
    }

    var runPath = GetNoteRunPath(root, runId);
    if (runPath is null)
    {
        return Results.NotFound(new { error = "Research notes run not found." });
    }

    var filePath = Path.Combine(runPath, fileName);
    return ReadTextFileResult(filePath);
});

app.MapGet("/api/inventories/{inventoryId}", (string inventoryId) =>
{
    var inventory = ListGameInventories(root)
        .FirstOrDefault(item => item.Id.Equals(inventoryId, StringComparison.OrdinalIgnoreCase));

    if (inventory is null)
    {
        return Results.NotFound(new { error = "Inventory was not found." });
    }

    var files = new List<object>();
    if (inventory.HasMarkdown)
    {
        var file = new FileInfo(inventory.MarkdownPath);
        files.Add(new
        {
            name = file.Name,
            sizeBytes = file.Length,
            lastWriteTime = file.LastWriteTime
        });
    }

    if (inventory.HasJson)
    {
        var file = new FileInfo(inventory.JsonPath);
        files.Add(new
        {
            name = file.Name,
            sizeBytes = file.Length,
            lastWriteTime = file.LastWriteTime
        });
    }

    object? summary = null;
    if (inventory.HasJson)
    {
        summary = JsonSerializer.Deserialize<object>(File.ReadAllText(inventory.JsonPath));
    }

    return Results.Json(new
    {
        id = inventory.Id,
        path = Path.GetDirectoryName(inventory.JsonPath) ?? Path.GetDirectoryName(inventory.MarkdownPath) ?? "",
        preferredFile = inventory.HasMarkdown
            ? Path.GetFileName(inventory.MarkdownPath)
            : Path.GetFileName(inventory.JsonPath),
        summary,
        files
    });
});

app.MapGet("/api/inventories/{inventoryId}/files/{fileName}", (string inventoryId, string fileName) =>
{
    if (!IsSafeFileName(fileName) || !IsDashboardTextArtifact(fileName))
    {
        return Results.BadRequest(new { error = "File is not exposed by the dashboard." });
    }

    var inventory = ListGameInventories(root)
        .FirstOrDefault(item => item.Id.Equals(inventoryId, StringComparison.OrdinalIgnoreCase));

    if (inventory is null)
    {
        return Results.NotFound(new { error = "Inventory was not found." });
    }

    var expectedNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        Path.GetFileName(inventory.JsonPath),
        Path.GetFileName(inventory.MarkdownPath)
    };

    if (!expectedNames.Contains(fileName))
    {
        return Results.BadRequest(new { error = "File is not exposed by the dashboard." });
    }

    var filePath = Path.Combine(Path.GetDirectoryName(inventory.JsonPath) ?? Path.GetDirectoryName(inventory.MarkdownPath) ?? "", fileName);
    return ReadTextFileResult(filePath);
});

app.Run();

static IResult StartDashboardJob(
    string root,
    DashboardJobState jobState,
    string label,
    string scriptPath,
    IReadOnlyList<string> scriptArgs)
{
    var result = jobState.TryStartScriptJob(root, label, scriptPath, scriptArgs);
    if (result.Started)
    {
        return Results.Accepted("/api/jobs/current", result.Snapshot);
    }

    return Results.Conflict(new { error = result.Error, snapshot = result.Snapshot });
}

static IReadOnlyList<string> BuildNamedArgs(params (string Name, string? Value)[] args)
{
    var values = new List<string>();
    foreach (var (name, value) in args)
    {
        if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(value))
        {
            continue;
        }

        values.Add(name);
        values.Add(value.Trim());
    }

    return values;
}

static object BuildDashboardState(
    string root,
    DashboardJobState jobState,
    DashboardServerState serverState,
    string serverScriptPath)
{
    var gamePath = ReadGamePath(root);
    var inventories = ListGameInventories(root);
    var fullResearchRuns = ListResearchRuns(root);
    var noteRuns = ListNoteRuns(root);
    var runtimeDumps = ListRuntimeDumps(root);

    return new
    {
        projectRoot = root,
        gamePath,
        ue4ssInstall = BuildUe4ssInstallState(root, gamePath),
        inventories,
        latestInventory = inventories.FirstOrDefault(),
        fullResearchRuns,
        latestRun = fullResearchRuns.FirstOrDefault(),
        noteRuns,
        latestNoteRun = noteRuns.FirstOrDefault(),
        runtimeDumps,
        latestRuntimeDump = runtimeDumps.FirstOrDefault(),
        summary = new
        {
            inventoryCount = inventories.Length,
            fullResearchCount = fullResearchRuns.Length,
            noteRunCount = noteRuns.Length,
            runtimeDumpCount = runtimeDumps.Length
        },
        job = jobState.Snapshot(),
        server = serverState.Snapshot(serverScriptPath)
    };
}

static object BuildUe4ssInstallState(string root, string gamePath)
{
    var requiredMods = new[]
    {
        "CyrodiilMP_RuntimeInspector"
    };

    if (string.IsNullOrWhiteSpace(gamePath))
    {
        return new
        {
            status = "missing-game-path",
            statusText = "Game path not set",
            installed = false,
            readyToInstall = false,
            gamePath = "",
            modsPath = "",
            enabledPath = "",
            details = new[]
            {
                CreateInstallDetail("Game path", false, "Save a local game path before installing UE4SS helpers.")
            }
        };
    }

    var trimmedGamePath = gamePath.Trim();
    var gameRootPath = Path.Combine(trimmedGamePath, "OblivionRemastered");
    var win64Path = Path.Combine(trimmedGamePath, "OblivionRemastered", "Binaries", "Win64");
    var paksPath = Path.Combine(trimmedGamePath, "OblivionRemastered", "Content", "Paks");
    var modsPath = Path.Combine(win64Path, "Mods");
    var modsListPath = Path.Combine(modsPath, "mods.txt");
    var looksLikeInstallRoot = Directory.Exists(gameRootPath) &&
        (Directory.Exists(win64Path) || Directory.Exists(paksPath));

    var details = new List<Ue4ssInstallDetail>
    {
        CreateInstallDetail("Game root", Directory.Exists(trimmedGamePath), trimmedGamePath),
        CreateInstallDetail("OblivionRemastered folder", Directory.Exists(gameRootPath), gameRootPath),
        CreateInstallDetail("Game layout hint", looksLikeInstallRoot, looksLikeInstallRoot ? "Expected game folders detected." : $"Expected {win64Path} or {paksPath}"),
        CreateInstallDetail("UE4SS Mods folder", Directory.Exists(modsPath), modsPath),
        CreateInstallDetail("mods.txt", File.Exists(modsListPath), modsListPath)
    };

    foreach (var modName in requiredMods)
    {
        var modScriptPath = Path.Combine(modsPath, modName, "Scripts", "main.lua");
        var enabled = IsUe4ssLuaModEnabled(modsPath, modName);
        details.Add(CreateInstallDetail(
            modName,
            File.Exists(modScriptPath) && enabled,
            File.Exists(modScriptPath)
                ? enabled ? "Installed and enabled." : "Installed but not enabled in mods.txt or via per-mod enabled.txt."
                : modScriptPath));
    }

    var missing = details.Where(detail => !detail.Ok).Select(detail => detail.Name).ToArray();
    var installed = missing.Length == 0;

    return new
    {
        status = installed ? "installed" : looksLikeInstallRoot ? Directory.Exists(modsPath) ? "partial" : "not-installed" : "invalid-game-path",
        statusText = installed ? "Installed" : looksLikeInstallRoot ? missing.Length == 1 ? $"{missing[0]} missing" : $"{missing.Length} items missing" : "Game path does not look like an install root",
        installed,
        readyToInstall = looksLikeInstallRoot,
        gamePath = trimmedGamePath,
        modsPath,
        modsListPath,
        details
    };
}

static Ue4ssInstallDetail CreateInstallDetail(string name, bool ok, string value)
{
    return new Ue4ssInstallDetail(name, ok, value);
}

static bool IsUe4ssLuaModEnabled(string modsPath, string modName)
{
    var modEnabledPath = Path.Combine(modsPath, modName, "enabled.txt");
    if (File.Exists(modEnabledPath))
    {
        return true;
    }

    var modsListPath = Path.Combine(modsPath, "mods.txt");
    if (!File.Exists(modsListPath))
    {
        return false;
    }

    var pattern = new System.Text.RegularExpressions.Regex(
        @"^\s*" + System.Text.RegularExpressions.Regex.Escape(modName) + @"\s*:\s*1\s*$",
        System.Text.RegularExpressions.RegexOptions.IgnoreCase);

    return File.ReadLines(modsListPath).Any(line => pattern.IsMatch(line));
}

static string FindProjectRoot()
{
    var envRoot = Environment.GetEnvironmentVariable("CYRODIILMP_ROOT");
    if (!string.IsNullOrWhiteSpace(envRoot) && Directory.Exists(envRoot))
    {
        return Path.GetFullPath(envRoot);
    }

    var current = new DirectoryInfo(AppContext.BaseDirectory);
    while (current is not null)
    {
        if (File.Exists(Path.Combine(current.FullName, "scripts", "full-research.ps1")))
        {
            return current.FullName;
        }

        current = current.Parent;
    }

    throw new InvalidOperationException("Could not find CyrodiilMP project root.");
}

static string ReadGamePath(string root)
{
    var gamePathFile = Path.Combine(root, "game-path.txt");
    return File.Exists(gamePathFile) ? File.ReadAllText(gamePathFile).Trim() : "";
}

static string WriteGamePath(string root, string? gamePath)
{
    var gamePathFile = Path.Combine(root, "game-path.txt");
    var trimmed = gamePath?.Trim() ?? "";

    if (string.IsNullOrWhiteSpace(trimmed))
    {
        if (File.Exists(gamePathFile))
        {
            File.Delete(gamePathFile);
        }

        return "";
    }

    File.WriteAllText(gamePathFile, trimmed + Environment.NewLine);
    return trimmed;
}

static ResearchRun[] ListResearchRuns(string root)
{
    var fullResearchPath = Path.Combine(root, "research", "full-research");
    if (!Directory.Exists(fullResearchPath))
    {
        return [];
    }

    return Directory.EnumerateDirectories(fullResearchPath, "research-*")
        .Select(path =>
        {
            var info = new DirectoryInfo(path);
            var summaryPath = Path.Combine(path, "summary.json");
            var reportPath = Path.Combine(path, "report.md");
            var createdAt = info.LastWriteTime;
            var gamePath = "";
            var totalFiles = 0;
            var packageFiles = 0;
            var legacyFiles = 0;

            if (File.Exists(summaryPath))
            {
                using var summary = JsonDocument.Parse(File.ReadAllText(summaryPath));
                var rootElement = summary.RootElement;
                createdAt = ReadDateTime(rootElement, "CreatedAt") ?? createdAt;
                gamePath = ReadString(rootElement, "GamePath");
                totalFiles = ReadInt(rootElement, "TotalFiles");
                packageFiles = ReadInt(rootElement, "PackageFiles");
                legacyFiles = ReadInt(rootElement, "LegacyDataFiles");
            }

            return new ResearchRun(
                info.Name,
                path,
                createdAt,
                gamePath,
                totalFiles,
                packageFiles,
                legacyFiles,
                File.Exists(reportPath));
        })
        .OrderByDescending(run => run.CreatedAt)
        .ToArray();
}

static NoteRun[] ListNoteRuns(string root)
{
    var notesPath = Path.Combine(root, "research", "runs");
    if (!Directory.Exists(notesPath))
    {
        return [];
    }

    return Directory.EnumerateDirectories(notesPath)
        .Select(path =>
        {
            var info = new DirectoryInfo(path);
            var notesFile = Path.Combine(path, "notes.md");
            var readmeFile = Path.Combine(path, "README.md");
            var statusFile = Path.Combine(path, "status.txt");
            var topLevelFiles = Directory.EnumerateFiles(path)
                .Select(file => new FileInfo(file))
                .Where(file => IsDashboardTextArtifact(file.Name))
                .Count();

            return new NoteRun(
                info.Name,
                path,
                info.LastWriteTime,
                File.Exists(notesFile),
                File.Exists(readmeFile),
                File.Exists(statusFile),
                topLevelFiles);
        })
        .OrderByDescending(run => run.CreatedAt)
        .ToArray();
}

static RuntimeDump[] ListRuntimeDumps(string root)
{
    var runtimeDumpPath = Path.Combine(root, "research", "runtime-dumps");
    if (!Directory.Exists(runtimeDumpPath))
    {
        return [];
    }

    return Directory.EnumerateDirectories(runtimeDumpPath)
        .Select(path =>
        {
            var info = new DirectoryInfo(path);
            var analysisPath = Path.Combine(path, "menu-analysis.md");
            var summaryPath = Path.Combine(path, "summary.md");
            var csvCount = Directory.EnumerateFiles(path, "*.csv").Count();

            return new RuntimeDump(
                info.Name,
                path,
                info.LastWriteTime,
                csvCount,
                File.Exists(analysisPath),
                File.Exists(summaryPath));
        })
        .OrderByDescending(dump => dump.CreatedAt)
        .ToArray();
}

static GameInventory[] ListGameInventories(string root)
{
    var inventoryPath = Path.Combine(root, "research", "game-inventory");
    if (!Directory.Exists(inventoryPath))
    {
        return [];
    }

    return Directory.EnumerateFiles(inventoryPath, "inventory-*.*")
        .Select(path => new FileInfo(path))
        .Where(file => file.Extension.Equals(".json", StringComparison.OrdinalIgnoreCase) ||
            file.Extension.Equals(".md", StringComparison.OrdinalIgnoreCase))
        .GroupBy(file => Path.GetFileNameWithoutExtension(file.Name), StringComparer.OrdinalIgnoreCase)
        .Select(group =>
        {
            var jsonFile = group.FirstOrDefault(file => file.Extension.Equals(".json", StringComparison.OrdinalIgnoreCase));
            var markdownFile = group.FirstOrDefault(file => file.Extension.Equals(".md", StringComparison.OrdinalIgnoreCase));
            var createdAt = group.Max(file => file.LastWriteTime);
            var gamePath = "";
            var fileCount = 0;

            if (jsonFile is not null)
            {
                using var summary = JsonDocument.Parse(File.ReadAllText(jsonFile.FullName));
                var rootElement = summary.RootElement;
                createdAt = ReadDateTime(rootElement, "CreatedAt") ?? createdAt;
                gamePath = ReadString(rootElement, "GamePath");
                fileCount = ReadInt(rootElement, "FileCount");
            }

            return new GameInventory(
                group.Key,
                createdAt,
                gamePath,
                fileCount,
                jsonFile?.FullName ?? "",
                markdownFile?.FullName ?? "",
                jsonFile is not null,
                markdownFile is not null);
        })
        .OrderByDescending(item => item.CreatedAt)
        .ToArray();
}

static string? GetRunPath(string root, string runId)
{
    if (!IsSafeFileName(runId))
    {
        return null;
    }

    var runPath = Path.Combine(root, "research", "full-research", runId);
    return Directory.Exists(runPath) ? runPath : null;
}

static string? GetRuntimeDumpPath(string root, string dumpId)
{
    if (!IsSafeFileName(dumpId))
    {
        return null;
    }

    var dumpPath = Path.Combine(root, "research", "runtime-dumps", dumpId);
    return Directory.Exists(dumpPath) ? dumpPath : null;
}

static string? GetNoteRunPath(string root, string runId)
{
    if (!IsSafeFileName(runId))
    {
        return null;
    }

    var runPath = Path.Combine(root, "research", "runs", runId);
    return Directory.Exists(runPath) ? runPath : null;
}

static bool IsSafeFileName(string value)
{
    return !string.IsNullOrWhiteSpace(value) &&
        !value.Contains("..") &&
        !value.Contains('/') &&
        !value.Contains('\\');
}

static bool IsDashboardTextArtifact(string fileName)
{
    var extension = Path.GetExtension(fileName).ToLowerInvariant();
    return extension is ".md" or ".csv" or ".json" or ".lua" or ".txt" or ".log";
}

static bool IsDashboardRuntimeFile(string fileName)
{
    return IsDashboardTextArtifact(fileName);
}

static IResult ReadTextFileResult(string filePath)
{
    if (!File.Exists(filePath))
    {
        return Results.NotFound(new { error = "File not found." });
    }

    return Results.Text(File.ReadAllText(filePath), GetContentType(filePath), Encoding.UTF8);
}

static DateTime? ReadDateTime(JsonElement element, string property)
{
    return element.TryGetProperty(property, out var value) && value.TryGetDateTime(out var date) ? date : null;
}

static string ReadString(JsonElement element, string property)
{
    return element.TryGetProperty(property, out var value) ? value.GetString() ?? "" : "";
}

static int ReadInt(JsonElement element, string property)
{
    return element.TryGetProperty(property, out var value) && value.TryGetInt32(out var number) ? number : 0;
}

static string GetContentType(string fileName)
{
    return Path.GetExtension(fileName).ToLowerInvariant() switch
    {
        ".json" => "application/json",
        ".csv" => "text/csv",
        ".md" => "text/markdown",
        ".lua" => "text/plain",
        ".log" => "text/plain",
        _ => "text/plain"
    };
}

record ResearchRun(
    string Id,
    string Path,
    DateTime CreatedAt,
    string GamePath,
    int TotalFiles,
    int PackageFiles,
    int LegacyDataFiles,
    bool HasReport);

record NoteRun(
    string Id,
    string Path,
    DateTime CreatedAt,
    bool HasNotes,
    bool HasReadme,
    bool HasStatus,
    int FileCount);

record RuntimeDump(
    string Id,
    string Path,
    DateTime CreatedAt,
    int CsvFiles,
    bool HasMenuAnalysis,
    bool HasSummary);

record GameInventory(
    string Id,
    DateTime CreatedAt,
    string GamePath,
    int FileCount,
    string JsonPath,
    string MarkdownPath,
    bool HasJson,
    bool HasMarkdown);

record GamePathRequest(string? GamePath);
record NameRequest(string? Name);
record NamedGamePathRequest(string? Name, string? GamePath);
record AnalyzeDumpRequest(string? DumpId);
record ClientBridgeRequest(string? HostName, int? Port, string? Name, string? Reason, int? TimeoutMs);
record ServerStartRequest(int? Port);
record GamePathUpdateRequest(string? GamePath);

sealed class DashboardJobState
{
    private readonly object gate = new();
    private readonly List<DashboardJob> history = new();
    private DashboardJob? activeJob;
    private Process? activeProcess;
    private int nextId;

    public object Snapshot()
    {
        lock (gate)
        {
            return new
            {
                isRunning = activeJob is { Status: "running" or "cancelling" },
                activeJob = activeJob is null ? null : ToDto(activeJob),
                recentJobs = history
                    .OrderByDescending(job => job.StartedAt)
                    .Take(12)
                    .Select(ToDto)
                    .ToArray(),
                status = activeJob?.Status ?? history.OrderByDescending(job => job.StartedAt).FirstOrDefault()?.Status ?? "idle"
            };
        }
    }

    public (bool Started, string Error, object Snapshot) TryStartScriptJob(
        string root,
        string label,
        string scriptPath,
        IReadOnlyList<string> scriptArgs)
    {
        Process? process = null;
        DashboardJob? job = null;

        lock (gate)
        {
            if (activeJob is { Status: "running" or "cancelling" })
            {
                return (false, "Another dashboard job is already running.", Snapshot());
            }

            if (!File.Exists(scriptPath))
            {
                return (false, $"Script was not found: {scriptPath}", Snapshot());
            }

            nextId++;
            job = new DashboardJob(
                $"job-{nextId:0000}",
                label,
                Path.GetFileName(scriptPath),
                DateTime.Now);

            history.Add(job);
            TrimHistory();
            activeJob = job;
        }

        try
        {
            process = CreatePowerShellProcess(root, scriptPath, scriptArgs);
            process.OutputDataReceived += (_, eventArgs) =>
            {
                if (!string.IsNullOrWhiteSpace(eventArgs.Data))
                {
                    AppendLog(job!, eventArgs.Data);
                }
            };
            process.ErrorDataReceived += (_, eventArgs) =>
            {
                if (!string.IsNullOrWhiteSpace(eventArgs.Data))
                {
                    AppendLog(job!, eventArgs.Data);
                }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            lock (gate)
            {
                activeProcess = process;
                job!.Command = BuildCommandPreview(scriptPath, scriptArgs);
            }

            _ = Task.Run(() => ObserveJobAsync(job!, process));
            return (true, "", Snapshot());
        }
        catch (Exception ex)
        {
            lock (gate)
            {
                if (job is not null)
                {
                    job.Status = "failed";
                    job.Error = ex.Message;
                    job.FinishedAt = DateTime.Now;
                }

                activeJob = null;
                activeProcess = null;
            }

            process?.Dispose();
            return (false, ex.Message, Snapshot());
        }
    }

    public (bool Cancelled, string Reason, object Snapshot) CancelActiveJob()
    {
        Process? process;

        lock (gate)
        {
            if (activeJob is not { Status: "running" or "cancelling" })
            {
                return (false, "There is no running dashboard job to cancel.", Snapshot());
            }

            activeJob.CancelRequested = true;
            activeJob.Status = "cancelling";
            process = activeProcess;
        }

        if (process is null)
        {
            return (false, "The active job process is not available.", Snapshot());
        }

        try
        {
            process.Kill(true);
            return (true, "", Snapshot());
        }
        catch (Exception ex)
        {
            AppendLog(activeJob!, $"Cancel failed: {ex.Message}");
            return (false, ex.Message, Snapshot());
        }
    }

    private async Task ObserveJobAsync(DashboardJob job, Process process)
    {
        try
        {
            await process.WaitForExitAsync();

            lock (gate)
            {
                job.ExitCode = process.ExitCode;
                job.FinishedAt = DateTime.Now;
                job.Status = job.CancelRequested
                    ? "cancelled"
                    : process.ExitCode == 0
                        ? "completed"
                        : "failed";

                if (ReferenceEquals(activeJob, job))
                {
                    activeJob = null;
                    activeProcess = null;
                }
            }
        }
        catch (Exception ex)
        {
            lock (gate)
            {
                job.Status = "failed";
                job.Error = ex.Message;
                job.FinishedAt = DateTime.Now;

                if (ReferenceEquals(activeJob, job))
                {
                    activeJob = null;
                    activeProcess = null;
                }
            }
        }
        finally
        {
            process.Dispose();
        }
    }

    private void AppendLog(DashboardJob job, string message)
    {
        lock (gate)
        {
            job.Log.Enqueue($"[{DateTime.Now:HH:mm:ss}] {message}");
            while (job.Log.Count > 500 && job.Log.TryDequeue(out _))
            {
            }
        }
    }

    private static Process CreatePowerShellProcess(
        string root,
        string scriptPath,
        IReadOnlyList<string> scriptArgs)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                WorkingDirectory = root,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            },
            EnableRaisingEvents = true
        };

        process.StartInfo.ArgumentList.Add("-NoProfile");
        process.StartInfo.ArgumentList.Add("-ExecutionPolicy");
        process.StartInfo.ArgumentList.Add("Bypass");
        process.StartInfo.ArgumentList.Add("-File");
        process.StartInfo.ArgumentList.Add(scriptPath);

        foreach (var arg in scriptArgs)
        {
            process.StartInfo.ArgumentList.Add(arg);
        }

        return process;
    }

    private static string BuildCommandPreview(string scriptPath, IReadOnlyList<string> scriptArgs)
    {
        var parts = new List<string> { "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $"\"{scriptPath}\"" };
        parts.AddRange(scriptArgs.Select(arg => arg.Contains(' ') ? $"\"{arg}\"" : arg));
        return string.Join(" ", parts);
    }

    private void TrimHistory()
    {
        if (history.Count <= 20)
        {
            return;
        }

        history.RemoveRange(0, history.Count - 20);
    }

    private static object ToDto(DashboardJob job)
    {
        return new
        {
            id = job.Id,
            label = job.Label,
            scriptName = job.ScriptName,
            command = job.Command,
            status = job.Status,
            startedAt = job.StartedAt,
            finishedAt = job.FinishedAt,
            exitCode = job.ExitCode,
            error = job.Error,
            cancelRequested = job.CancelRequested,
            log = job.Log.ToArray()
        };
    }

    private sealed class DashboardJob(
        string id,
        string label,
        string scriptName,
        DateTime startedAt)
    {
        public string Id { get; } = id;
        public string Label { get; } = label;
        public string ScriptName { get; } = scriptName;
        public DateTime StartedAt { get; } = startedAt;
        public ConcurrentQueue<string> Log { get; } = new();
        public string Status { get; set; } = "running";
        public string Command { get; set; } = "";
        public DateTime? FinishedAt { get; set; }
        public int? ExitCode { get; set; }
        public string Error { get; set; } = "";
        public bool CancelRequested { get; set; }
    }
}

sealed class DashboardServerState
{
    private readonly object gate = new();
    private readonly ConcurrentQueue<string> log = new();
    private Process? process;
    private string status = "stopped";
    private DateTime? startedAt;
    private DateTime? finishedAt;
    private int? exitCode;
    private int port = CyrodiilProtocol.DefaultPort;
    private bool stopRequested;
    private string command = "";

    public object Snapshot(string scriptPath)
    {
        var lingering = FindServerProcesses();

        lock (gate)
        {
            return new
            {
                running = process is not null && !process.HasExited,
                status,
                processId = process is not null && !process.HasExited ? process.Id : (int?)null,
                port,
                startedAt,
                finishedAt,
                exitCode,
                command,
                launchScriptPath = scriptPath,
                scriptExists = File.Exists(scriptPath),
                lingeringCount = lingering.Length,
                lingeringProcesses = lingering,
                log = log.ToArray().TakeLast(250).ToArray()
            };
        }
    }

    public (bool Started, string Reason, object Snapshot) Start(string root, string scriptPath, int requestedPort)
    {
        Process? startedProcess = null;

        lock (gate)
        {
            if (process is not null && !process.HasExited)
            {
                return (false, "The dashboard server helper is already running.", Snapshot(scriptPath));
            }

            if (!File.Exists(scriptPath))
            {
                return (false, $"Server script was not found: {scriptPath}", Snapshot(scriptPath));
            }

            while (log.TryDequeue(out _))
            {
            }

            status = "starting";
            startedAt = DateTime.Now;
            finishedAt = null;
            exitCode = null;
            port = requestedPort;
            stopRequested = false;
            command = "";
        }

        try
        {
            startedProcess = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    WorkingDirectory = root,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                },
                EnableRaisingEvents = true
            };

            startedProcess.StartInfo.ArgumentList.Add("-NoProfile");
            startedProcess.StartInfo.ArgumentList.Add("-ExecutionPolicy");
            startedProcess.StartInfo.ArgumentList.Add("Bypass");
            startedProcess.StartInfo.ArgumentList.Add("-File");
            startedProcess.StartInfo.ArgumentList.Add(scriptPath);
            startedProcess.StartInfo.ArgumentList.Add("-Port");
            startedProcess.StartInfo.ArgumentList.Add(requestedPort.ToString());

            startedProcess.OutputDataReceived += (_, eventArgs) =>
            {
                if (!string.IsNullOrWhiteSpace(eventArgs.Data))
                {
                    AppendLog(eventArgs.Data);
                }
            };
            startedProcess.ErrorDataReceived += (_, eventArgs) =>
            {
                if (!string.IsNullOrWhiteSpace(eventArgs.Data))
                {
                    AppendLog(eventArgs.Data);
                }
            };

            startedProcess.Start();
            startedProcess.BeginOutputReadLine();
            startedProcess.BeginErrorReadLine();

            lock (gate)
            {
                process = startedProcess;
                status = "running";
                command = $"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\" -Port {requestedPort}";
            }

            _ = Task.Run(() => ObserveServerAsync(startedProcess));
            return (true, "", Snapshot(scriptPath));
        }
        catch (Exception ex)
        {
            lock (gate)
            {
                status = "failed";
                finishedAt = DateTime.Now;
                exitCode = -1;
                process = null;
            }

            AppendLog(ex.Message);
            startedProcess?.Dispose();
            return (false, ex.Message, Snapshot(scriptPath));
        }
    }

    public (bool Stopped, string Reason, object Snapshot) Stop(string scriptPath)
    {
        Process? currentProcess;

        lock (gate)
        {
            if (process is null || process.HasExited)
            {
                return (false, "The helper-managed server is not running.", Snapshot(scriptPath));
            }

            stopRequested = true;
            status = "stopping";
            currentProcess = process;
        }

        try
        {
            currentProcess.Kill(true);
            return (true, "", Snapshot(scriptPath));
        }
        catch (Exception ex)
        {
            AppendLog($"Stop failed: {ex.Message}");
            return (false, ex.Message, Snapshot(scriptPath));
        }
    }

    public (bool Stopped, string Reason, object Snapshot) ForceStop(string scriptPath)
    {
        var killed = new List<int>();
        var failures = new List<string>();
        var trackedProcessId = 0;

        lock (gate)
        {
            if (process is not null && !process.HasExited)
            {
                trackedProcessId = process.Id;
                stopRequested = true;
                status = "stopping";
            }
        }

        if (trackedProcessId > 0)
        {
            TryKillProcessTree(trackedProcessId, killed, failures);
        }

        foreach (var lingering in FindServerProcesses())
        {
            if (trackedProcessId > 0 && lingering.ProcessId == trackedProcessId)
            {
                continue;
            }

            TryKillProcessTree(lingering.ProcessId, killed, failures);
        }

        if (killed.Count == 0 && failures.Count == 0)
        {
            return (false, "No lingering CyrodiilMP server processes were found.", Snapshot(scriptPath));
        }

        lock (gate)
        {
            if (trackedProcessId > 0)
            {
                process = null;
                finishedAt = DateTime.Now;
                status = failures.Count == 0 ? "stopped" : "failed";
                exitCode = failures.Count == 0 ? 0 : -1;
            }
        }

        if (killed.Count > 0)
        {
            AppendLog($"Force-killed server processes: {string.Join(", ", killed.Distinct().OrderBy(id => id))}");
        }

        foreach (var failure in failures)
        {
            AppendLog(failure);
        }

        return failures.Count == 0
            ? (true, "", Snapshot(scriptPath))
            : (false, "One or more server processes could not be force-killed.", Snapshot(scriptPath));
    }

    private async Task ObserveServerAsync(Process observedProcess)
    {
        try
        {
            await observedProcess.WaitForExitAsync();

            lock (gate)
            {
                if (!ReferenceEquals(process, observedProcess))
                {
                    return;
                }

                exitCode = observedProcess.ExitCode;
                finishedAt = DateTime.Now;
                status = stopRequested
                    ? "stopped"
                    : observedProcess.ExitCode == 0
                        ? "stopped"
                        : "failed";
                process = null;
            }
        }
        catch (Exception ex)
        {
            AppendLog(ex.Message);
            lock (gate)
            {
                if (ReferenceEquals(process, observedProcess))
                {
                    status = "failed";
                    finishedAt = DateTime.Now;
                    exitCode = -1;
                    process = null;
                }
            }
        }
        finally
        {
            observedProcess.Dispose();
        }
    }

    private void AppendLog(string message)
    {
        log.Enqueue($"[{DateTime.Now:HH:mm:ss}] {message}");
        while (log.Count > 500 && log.TryDequeue(out _))
        {
        }
    }

    private static DashboardServerProcessInfo[] FindServerProcesses()
    {
        try
        {
            return Process.GetProcesses()
                .Select(process =>
                {
                    try
                    {
                        var name = process.ProcessName;
                        var fileName = "";

                        try
                        {
                            fileName = process.MainModule?.FileName ?? "";
                        }
                        catch
                        {
                        }

                        return new DashboardServerProcessInfo(
                            process.Id,
                            name,
                            fileName);
                    }
                    finally
                    {
                        process.Dispose();
                    }
                })
                .Where(info => LooksLikeServerProcess(info))
                .OrderBy(info => info.ProcessId)
                .ToArray();
        }
        catch
        {
            return [];
        }
    }

    private static bool LooksLikeServerProcess(DashboardServerProcessInfo info)
    {
        if (info.ProcessName.Equals("CyrodiilMP.Server", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return info.FileName.Contains("CyrodiilMP.Server.exe", StringComparison.OrdinalIgnoreCase);
    }

    private static void TryKillProcessTree(int processId, List<int> killed, List<string> failures)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            process.Kill(true);
            killed.Add(processId);
        }
        catch (ArgumentException)
        {
        }
        catch (Exception ex)
        {
            failures.Add($"Force kill failed for PID {processId}: {ex.Message}");
        }
    }
}

sealed record DashboardServerProcessInfo(
    int ProcessId,
    string ProcessName,
    string FileName);

sealed record Ue4ssInstallDetail(
    string Name,
    bool Ok,
    string Value);

static class CyrodiilProtocol
{
    public const int DefaultPort = 27015;
    public const string DefaultHost = "127.0.0.1";
}
