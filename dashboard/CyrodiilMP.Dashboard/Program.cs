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

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/api/state", () =>
{
    var gamePath = ReadGamePath(root);
    var runs = ListResearchRuns(root);
    var runtimeDumps = ListRuntimeDumps(root);

    return Results.Json(new
    {
        projectRoot = root,
        gamePath,
        latestRun = runs.FirstOrDefault(),
        latestRuntimeDump = runtimeDumps.FirstOrDefault(),
        runs,
        runtimeDumps,
        job = jobState.Snapshot()
    });
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
        report = File.Exists(reportPath) ? File.ReadAllText(reportPath) : "",
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
    if (!File.Exists(filePath))
    {
        return Results.NotFound(new { error = "File not found." });
    }

    return Results.Text(File.ReadAllText(filePath), GetContentType(fileName), Encoding.UTF8);
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

    var preferredReport = File.Exists(Path.Combine(dumpPath, "menu-analysis.md"))
        ? "menu-analysis.md"
        : File.Exists(Path.Combine(dumpPath, "summary.md"))
            ? "summary.md"
            : files.FirstOrDefault()?.name ?? "";

    return Results.Json(new
    {
        id = dumpId,
        path = dumpPath,
        preferredReport,
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
    if (!File.Exists(filePath))
    {
        return Results.NotFound(new { error = "File not found." });
    }

    return Results.Text(File.ReadAllText(filePath), GetContentType(fileName), Encoding.UTF8);
});

app.MapPost("/api/runtime-dumps/{dumpId}/analyze", async (string dumpId) =>
{
    var dumpPath = GetRuntimeDumpPath(root, dumpId);
    if (dumpPath is null)
    {
        return Results.NotFound(new { error = "Runtime dump not found." });
    }

    var script = Path.Combine(root, "scripts", "analyze-runtime-dump.ps1");
    var process = new Process
    {
        StartInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            ArgumentList =
            {
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                script,
                "-DumpPath",
                dumpPath
            },
            WorkingDirectory = root,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        }
    };

    process.Start();
    var outputTask = process.StandardOutput.ReadToEndAsync();
    var errorTask = process.StandardError.ReadToEndAsync();
    await process.WaitForExitAsync();

    return Results.Json(new
    {
        exitCode = process.ExitCode,
        output = await outputTask,
        error = await errorTask
    });
});

app.MapPost("/api/research/full", async (ResearchRequest request) =>
{
    if (jobState.IsRunning)
    {
        return Results.Conflict(new { error = "A research job is already running.", job = jobState.Snapshot() });
    }

    var gamePath = string.IsNullOrWhiteSpace(request.GamePath) ? ReadGamePath(root) : request.GamePath.Trim();
    if (string.IsNullOrWhiteSpace(gamePath))
    {
        return Results.BadRequest(new { error = "No game path configured. Add game-path.txt or pass gamePath." });
    }

    await jobState.StartAsync(root, gamePath);
    return Results.Json(new { job = jobState.Snapshot() });
});

app.MapGet("/api/jobs/current", () => Results.Json(jobState.Snapshot()));

app.Run();

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

static string? GetRunPath(string root, string runId)
{
    if (runId.Contains("..") || runId.Contains('/') || runId.Contains('\\'))
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

static bool IsSafeFileName(string value)
{
    return !string.IsNullOrWhiteSpace(value) &&
        !value.Contains("..") &&
        !value.Contains('/') &&
        !value.Contains('\\');
}

static bool IsDashboardRuntimeFile(string fileName)
{
    var extension = Path.GetExtension(fileName).ToLowerInvariant();
    return extension is ".md" or ".csv" or ".json" or ".lua" or ".txt" or ".log";
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

record RuntimeDump(
    string Id,
    string Path,
    DateTime CreatedAt,
    int CsvFiles,
    bool HasMenuAnalysis,
    bool HasSummary);

record ResearchRequest(string? GamePath);

sealed class DashboardJobState
{
    private readonly object gate = new();
    private readonly ConcurrentQueue<string> log = new();
    private string id = "";
    private bool isRunning;
    private DateTime? startedAt;
    private DateTime? finishedAt;
    private int? exitCode;
    private string status = "idle";

    public bool IsRunning
    {
        get
        {
            lock (gate)
            {
                return isRunning;
            }
        }
    }

    public object Snapshot()
    {
        lock (gate)
        {
            return new
            {
                id,
                isRunning,
                startedAt,
                finishedAt,
                exitCode,
                status,
                log = log.ToArray().TakeLast(200).ToArray()
            };
        }
    }

    public Task StartAsync(string root, string gamePath)
    {
        lock (gate)
        {
            id = DateTimeOffset.Now.ToString("yyyyMMdd-HHmmss");
            isRunning = true;
            startedAt = DateTime.Now;
            finishedAt = null;
            exitCode = null;
            status = "running";
            while (log.TryDequeue(out _))
            {
            }
        }

        _ = Task.Run(async () =>
        {
            try
            {
                AddLog($"Starting full research for {gamePath}");
                var script = Path.Combine(root, "scripts", "full-research.ps1");
                var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        ArgumentList =
                        {
                            "-NoProfile",
                            "-ExecutionPolicy",
                            "Bypass",
                            "-File",
                            script,
                            "-GamePath",
                            gamePath
                        },
                        WorkingDirectory = root,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    },
                    EnableRaisingEvents = true
                };

                process.OutputDataReceived += (_, args) =>
                {
                    if (!string.IsNullOrWhiteSpace(args.Data))
                    {
                        AddLog(args.Data);
                    }
                };
                process.ErrorDataReceived += (_, args) =>
                {
                    if (!string.IsNullOrWhiteSpace(args.Data))
                    {
                        AddLog(args.Data);
                    }
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                await process.WaitForExitAsync();

                lock (gate)
                {
                    exitCode = process.ExitCode;
                    status = process.ExitCode == 0 ? "completed" : "failed";
                    isRunning = false;
                    finishedAt = DateTime.Now;
                }

                AddLog($"Research job finished with exit code {process.ExitCode}.");
            }
            catch (Exception ex)
            {
                AddLog(ex.ToString());
                lock (gate)
                {
                    exitCode = -1;
                    status = "failed";
                    isRunning = false;
                    finishedAt = DateTime.Now;
                }
            }
        });

        return Task.CompletedTask;
    }

    private void AddLog(string message)
    {
        log.Enqueue($"[{DateTime.Now:HH:mm:ss}] {message}");
        while (log.Count > 500 && log.TryDequeue(out _))
        {
        }
    }
}
