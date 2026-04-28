using System.Text.Json;
using CyrodiilMP.Protocol;
using LiteNetLib;

var options = BridgeOptions.Parse(args);
var result = await RunAsync(options);
var jsonOptions = new JsonSerializerOptions { WriteIndented = true };

if (!string.IsNullOrWhiteSpace(options.ResultPath))
{
    var resultPath = Path.GetFullPath(options.ResultPath);
    Directory.CreateDirectory(Path.GetDirectoryName(resultPath) ?? ".");
    await File.WriteAllTextAsync(resultPath, JsonSerializer.Serialize(result, jsonOptions));
}

Console.WriteLine(JsonSerializer.Serialize(result, jsonOptions));
return result.Success ? 0 : 1;

static async Task<BridgeResult> RunAsync(BridgeOptions options)
{
    var listener = new EventBasedNetListener();
    var client = new NetManager(listener)
    {
        AutoRecycle = true,
        IPv6Enabled = false
    };
    var deadline = DateTimeOffset.UtcNow + options.Timeout;
    var sentAt = (DateTimeOffset?)null;
    var failure = (BridgeResult?)null;
    var welcomePlayerId = (int?)null;

    listener.PeerConnectedEvent += peer =>
    {
        try
        {
            peer.Send(CyrodiilProtocol.CreateHello(options.Name, "ue4ss-menu"), DeliveryMethod.ReliableOrdered);
            peer.Send(CyrodiilProtocol.CreateMenuConnectRequest(options.Name, options.Reason), DeliveryMethod.ReliableOrdered);
            sentAt = DateTimeOffset.UtcNow;
        }
        catch (Exception ex)
        {
            failure = BridgeResult.Failed(options, "send-failed", ex.Message);
        }
    };

    listener.PeerDisconnectedEvent += (_, info) =>
    {
        failure ??= BridgeResult.Failed(options, "disconnected", info.Reason.ToString());
    };

    listener.NetworkErrorEvent += (_, error) =>
    {
        failure ??= BridgeResult.Failed(options, "network-error", error.ToString());
    };

    listener.NetworkReceiveEvent += (_, reader, _, _) =>
    {
        var payload = reader.GetRemainingBytes();
        var text = CyrodiilProtocol.DecodePreview(payload);
        if (text.StartsWith("server-welcome ", StringComparison.Ordinal))
        {
            var match = System.Text.RegularExpressions.Regex.Match(text, @"player_id=(\d+)");
            if (match.Success && int.TryParse(match.Groups[1].Value, out var pid))
            {
                welcomePlayerId = pid;
            }
            else
            {
                welcomePlayerId = 0;
            }
        }
    };

    if (!client.Start())
    {
        return BridgeResult.Failed(options, "client-start-failed", "NetManager.Start returned false.");
    }

    client.Connect(options.Host, options.Port, CyrodiilProtocol.ConnectionKey);

    while (DateTimeOffset.UtcNow < deadline)
    {
        client.PollEvents();

        if (failure is not null)
        {
            client.Stop();
            return failure;
        }

        if (welcomePlayerId is not null)
        {
            client.Stop();
            return new BridgeResult(
                true,
                DateTimeOffset.Now,
                options.Host,
                options.Port,
                options.Name,
                options.Reason,
                welcomePlayerId.Value,
                "server-welcome-received",
                "");
        }

        await Task.Delay(15);
    }

    client.Stop();
    var timeoutReason = sentAt is null ? "no-connection" : "no-server-welcome";
    return BridgeResult.Failed(options, "timeout", $"{timeoutReason} within {options.Timeout.TotalMilliseconds:0} ms.");
}

sealed record BridgeOptions(
    string Host,
    int Port,
    string Name,
    string Reason,
    TimeSpan Timeout,
    string ResultPath)
{
    public static BridgeOptions Parse(string[] args)
    {
        return new BridgeOptions(
            GetOption(args, "--host", CyrodiilProtocol.DefaultHost),
            int.Parse(GetOption(args, "--port", CyrodiilProtocol.DefaultPort.ToString())),
            GetOption(args, "--name", "OblivionPlayer"),
            GetOption(args, "--reason", "main-menu-connect"),
            TimeSpan.FromMilliseconds(int.Parse(GetOption(args, "--timeout-ms", "1800"))),
            GetOption(args, "--out", ""));
    }

    private static string GetOption(string[] args, string name, string fallback)
    {
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i].Equals(name, StringComparison.OrdinalIgnoreCase))
            {
                return args[i + 1];
            }
        }

        return fallback;
    }
}

sealed record BridgeResult(
    bool Success,
    DateTimeOffset Time,
    string Host,
    int Port,
    string Name,
    string Reason,
    int? PlayerId,
    string Status,
    string Error)
{
    public static BridgeResult Failed(BridgeOptions options, string status, string error)
    {
        return new BridgeResult(
            false,
            DateTimeOffset.Now,
            options.Host,
            options.Port,
            options.Name,
            options.Reason,
            null,
            status,
            error);
    }
}
