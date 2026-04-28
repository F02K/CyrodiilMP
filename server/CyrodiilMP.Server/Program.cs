using System.Collections.Generic;
using System.Net;
using CyrodiilMP.Protocol;
using LiteNetLib;

var port = GetPort(args);
var playerIdCounter = 0;

var listener = new EventBasedNetListener();
var server = new NetManager(listener)
{
    AutoRecycle = true,
    IPv6Enabled = false
};
var welcomedPeers = new HashSet<int>();

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
    welcomedPeers.Remove(peer.Id);
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
            if (welcomedPeers.Add(peer.Id))
            {
                peer.Send(
                    CyrodiilProtocol.CreateServerWelcome(peer.Id, CyrodiilProtocol.DefaultServerTickRate),
                    DeliveryMethod.ReliableOrdered);
                Console.WriteLine(
                    $"{Now()} welcome-sent peer={peer.Id} name={message.Get("name", "unknown")} source={message.Get("source", "unknown")}");
            }
        }
        else if (message.Verb.Equals("menu-connect", StringComparison.OrdinalIgnoreCase))
        {
            peer.Send(
                CyrodiilProtocol.CreateMenuConnectAck(peer.Id, "received"),
                DeliveryMethod.ReliableOrdered);
            Console.WriteLine(
                $"{Now()} menu-connect peer={peer.Id} name={message.Get("name", "unknown")} reason={message.Get("reason", "unknown")}");
        }
    }

    Console.WriteLine(
        $"{Now()} packet peer={peer.Id} bytes={payload.Length} channel={channel} method={method} preview={preview} text=\"{text}\"");

    if (text.StartsWith("menu-connect ", StringComparison.Ordinal))
    {
        var playerId = Interlocked.Increment(ref playerIdCounter);
        var welcome = CyrodiilProtocol.CreateServerWelcome(playerId, "CyrodiilMP");
        peer.Send(welcome, DeliveryMethod.ReliableOrdered);
        Console.WriteLine($"{Now()} sent server-welcome peer={peer.Id} player_id={playerId}");
    }
};

Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    server.Stop();
};

if (!server.Start(port))
{
    Console.Error.WriteLine($"Could not start CyrodiilMP server on UDP port {port}.");
    return 1;
}

Console.WriteLine($"{Now()} CyrodiilMP server listening on UDP port {port}");
Console.WriteLine($"{Now()} connection key: {CyrodiilProtocol.ConnectionKey}");
Console.WriteLine("Press Ctrl+C to stop.");

while (server.IsRunning)
{
    server.PollEvents();
    Thread.Sleep(15);
}

Console.WriteLine($"{Now()} CyrodiilMP server stopped.");
return 0;

static int GetPort(string[] args)
{
    if (args.Length == 0)
    {
        return CyrodiilProtocol.DefaultPort;
    }

    if (args.Length == 2 && args[0] is "--port" or "-p" && int.TryParse(args[1], out var port))
    {
        return port;
    }

    throw new ArgumentException("Usage: CyrodiilMP.Server [--port 27015]");
}

static string Now() => DateTimeOffset.Now.ToString("HH:mm:ss.fff");
