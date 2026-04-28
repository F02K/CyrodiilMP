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
    try
    {
        var deadline = DateTimeOffset.UtcNow + options.Timeout;
        var sentAt = (DateTimeOffset?)null;
        var failure = (BridgeResult?)null;
        var welcome = (ServerWelcome?)null;
        var menuAck = (MenuConnectAck?)null;

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
            var message = CyrodiilProtocol.ParseMessage(payload);
            if (message is null)
            {
                return;
            }

            if (message.Verb.Equals("server-welcome", StringComparison.OrdinalIgnoreCase))
            {
                welcome = new ServerWelcome(
                    message.GetInt("player"),
                    message.GetInt("tick_rate"),
                    message.GetInt("protocol", -1));
                return;
            }

            if (message.Verb.Equals("menu-connect-ack", StringComparison.OrdinalIgnoreCase))
            {
                menuAck = new MenuConnectAck(
                    message.GetInt("player"),
                    message.Get("status", ""));
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
                return failure;
            }

            if (welcome is not null)
            {
                return new BridgeResult(
                    true,
                    DateTimeOffset.Now,
                    options.Host,
                    options.Port,
                    options.Name,
                    options.Reason,
                    "welcome-received",
                    "",
                    welcome.PlayerId,
                    welcome.TickRate,
                    welcome.Protocol,
                    menuAck?.Status ?? "");
            }

            if (sentAt is not null && DateTimeOffset.UtcNow - sentAt.Value > TimeSpan.FromMilliseconds(500) && menuAck is not null)
            {
                return new BridgeResult(
                    true,
                    DateTimeOffset.Now,
                    options.Host,
                    options.Port,
                    options.Name,
                    options.Reason,
                    "menu-ack-received",
                    "",
                    menuAck.PlayerId,
                    0,
                    CyrodiilProtocol.ProtocolVersion,
                    menuAck.Status);
            }

            await Task.Delay(15);
        }

        return BridgeResult.Failed(options, "timeout", $"No connection within {options.Timeout.TotalMilliseconds:0} ms.");
    }
    finally
    {
        client.Stop();
    }
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
    string Status,
    string Error,
    int AssignedPlayerId,
    int ServerTickRate,
    int ServerProtocol,
    string MenuConnectAckStatus)
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
            status,
            error,
            0,
            0,
            -1,
            "");
    }
}

sealed record ServerWelcome(int PlayerId, int TickRate, int Protocol);
sealed record MenuConnectAck(int PlayerId, string Status);
