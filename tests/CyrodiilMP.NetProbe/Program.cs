using System.Text;
using LiteNetLib;

var host = GetOption(args, "--host", "127.0.0.1");
var port = int.Parse(GetOption(args, "--port", "27015"));
var name = GetOption(args, "--name", "ProbePlayer");

var listener = new EventBasedNetListener();
var client = new NetManager(listener)
{
    AutoRecycle = true,
    IPv6Enabled = false
};

NetPeer? peer = null;

listener.PeerConnectedEvent += connectedPeer =>
{
    peer = connectedPeer;
    Console.WriteLine($"{Now()} connected to {host}:{port}");
};

listener.PeerDisconnectedEvent += (_, info) =>
{
    peer = null;
    Console.WriteLine($"{Now()} disconnected reason={info.Reason}");
};

listener.NetworkErrorEvent += (endpoint, error) =>
{
    Console.WriteLine($"{Now()} network-error endpoint={endpoint} error={error}");
};

client.Start();
client.Connect(host, port, "CyrodiilMP");

Console.WriteLine($"{Now()} connecting as {name}");
Console.WriteLine("Press Ctrl+C to stop.");

var running = true;
Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    running = false;
};

var tick = 0;
while (running)
{
    client.PollEvents();

    if (peer is { ConnectionState: ConnectionState.Connected })
    {
        var x = MathF.Sin(tick * 0.1f) * 100.0f;
        var y = MathF.Cos(tick * 0.1f) * 100.0f;
        var z = 0.0f;
        var yaw = (tick * 5) % 360;
        var payload = Encoding.UTF8.GetBytes(
            $"transform name={name} tick={tick} x={x:0.00} y={y:0.00} z={z:0.00} yaw={yaw}");

        peer.Send(payload, DeliveryMethod.Unreliable);
        Console.WriteLine($"{Now()} sent fake transform tick={tick}");
        tick++;
        Thread.Sleep(100);
    }
    else
    {
        Thread.Sleep(15);
    }
}

client.Stop();
return 0;

static string GetOption(string[] args, string name, string fallback)
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

static string Now() => DateTimeOffset.Now.ToString("HH:mm:ss.fff");
