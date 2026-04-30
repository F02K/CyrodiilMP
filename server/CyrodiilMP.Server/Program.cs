using System.Net;
using CyrodiilMP.Protocol;
using CyrodiilMP.Server;
using LiteNetLib;

var port = GetPort(args);
var nativePort = GetNativePort(args, CyrodiilProtocol.DefaultNativeUdpPort);
var playerIdCounter = 0;

var listener = new EventBasedNetListener();
var server = new NetManager(listener)
{
    AutoRecycle = true,
    IPv6Enabled = false
};
var nativeSidecar = new NativeUdpSidecar(nativePort);
var playerIds = new Dictionary<int, int>();

listener.ConnectionRequestEvent += request =>
{
    if (server.ConnectedPeersCount >= 64)
    {
        request.Reject();
        return;
    }

    request.AcceptIfKey(CyrodiilProtocol.ConnectionKey);
};

listener.PeerConnectedEvent += peer =>
{
    Console.WriteLine($"{Now()} connected peer={peer.Id} endpoint={peer.Address}:{peer.Port}");
};

listener.PeerDisconnectedEvent += (peer, info) =>
{
    playerIds.Remove(peer.Id);
    Console.WriteLine($"{Now()} disconnected peer={peer.Id} reason={info.Reason}");
};

listener.NetworkErrorEvent += (endpoint, socketError) =>
{
    Console.WriteLine($"{Now()} network-error endpoint={endpoint} error={socketError}");
};

listener.NetworkReceiveEvent += (peer, reader, channel, method) =>
{
    var payload = reader.GetRemainingBytes();
    var preview = Convert.ToHexString(payload.AsSpan(0, Math.Min(payload.Length, 32)));
    var text = CyrodiilProtocol.DecodePreview(payload);

    var message = CyrodiilProtocol.ParseMessage(payload);
    if (message is not null)
    {
        if (message.Verb.Equals("hello", StringComparison.OrdinalIgnoreCase))
        {
            if (!playerIds.TryGetValue(peer.Id, out var playerId))
            {
                playerId = Interlocked.Increment(ref playerIdCounter);
                playerIds[peer.Id] = playerId;

                peer.Send(
                    CyrodiilProtocol.CreateServerWelcome(playerId, CyrodiilProtocol.DefaultServerTickRate),
                    DeliveryMethod.ReliableOrdered);
                Console.WriteLine(
                    $"{Now()} welcome-sent peer={peer.Id} player={playerId} name={message.Get("name", "unknown")} source={message.Get("source", "unknown")}");
            }
        }
        else if (message.Verb.Equals("menu-connect", StringComparison.OrdinalIgnoreCase))
        {
            if (!playerIds.TryGetValue(peer.Id, out var playerId))
            {
                playerId = Interlocked.Increment(ref playerIdCounter);
                playerIds[peer.Id] = playerId;
            }

            peer.Send(
                CyrodiilProtocol.CreateMenuConnectAck(playerId, "received"),
                DeliveryMethod.ReliableOrdered);
            Console.WriteLine(
                $"{Now()} menu-connect peer={peer.Id} player={playerId} name={message.Get("name", "unknown")} reason={message.Get("reason", "unknown")}");
        }
    }

    Console.WriteLine(
        $"{Now()} packet peer={peer.Id} bytes={payload.Length} channel={channel} method={method} preview={preview} text=\"{text}\"");
};

Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    server.Stop();
    _ = nativeSidecar.StopAsync();
};

if (!server.Start(port))
{
    Console.Error.WriteLine($"Could not start CyrodiilMP server on UDP port {port}.");
    return 1;
}

Console.WriteLine($"{Now()} CyrodiilMP server listening on UDP port {port}");
nativeSidecar.Start();
Console.WriteLine($"{Now()} connection key: {CyrodiilProtocol.ConnectionKey}");
Console.WriteLine($"{Now()} native UDP sidecar port: {nativePort}");
Console.WriteLine("Press Ctrl+C to stop.");

while (server.IsRunning)
{
    server.PollEvents();
    Thread.Sleep(15);
}

Console.WriteLine($"{Now()} CyrodiilMP server stopped.");
await nativeSidecar.StopAsync();
return 0;

static int GetPort(string[] args)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (args[i] is "--port" or "-p" && int.TryParse(args[i + 1], out var port))
        {
            return port;
        }
    }

    return CyrodiilProtocol.DefaultPort;
}

static int GetNativePort(string[] args, int fallback)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (args[i] is "--native-port" or "-n" && int.TryParse(args[i + 1], out var port))
        {
            return port;
        }
    }

    return fallback;
}

static string Now() => DateTimeOffset.Now.ToString("HH:mm:ss.fff");
