using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Text;
using CyrodiilMP.Protocol;

namespace CyrodiilMP.Server;

sealed class NativeUdpSidecar
{
    private static readonly TimeSpan ClientTimeout = TimeSpan.FromSeconds(5);

    private readonly int port;
    private readonly CancellationTokenSource stop = new();
    private readonly Dictionary<IPEndPoint, ClientState> clients = new();
    private int nextPlayerId;
    private UdpClient? udp;
    private Thread? thread;

    public NativeUdpSidecar(int port)
    {
        this.port = port;
    }

    public void Start()
    {
        udp = new UdpClient(new IPEndPoint(IPAddress.Any, port));
        udp.Client.ReceiveTimeout = 250;
        Console.WriteLine($"{Now()} cyro-udp listening on UDP port {port}");
        thread = new Thread(() => Run(udp))
        {
            IsBackground = true,
            Name = "CyrodiilMP UDP Sidecar"
        };
        thread.Start();
    }

    public Task StopAsync()
    {
        stop.Cancel();
        udp?.Dispose();
        if (thread is not null && thread.IsAlive)
        {
            thread.Join(TimeSpan.FromSeconds(1));
        }

        return Task.CompletedTask;
    }

    private void Run(UdpClient udp)
    {
        try
        {
            Console.WriteLine($"{Now()} cyro-udp receive loop started");
            while (!stop.IsCancellationRequested)
            {
                try
                {
                    var remote = new IPEndPoint(IPAddress.Any, 0);
                    var buffer = udp.Receive(ref remote);
                    ProcessPacket(udp, buffer, remote);
                }
                catch (SocketException ex) when (ex.SocketErrorCode == SocketError.TimedOut)
                {
                }

                PruneTimedOutClients(udp);
            }
        }
        catch (ObjectDisposedException) when (stop.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"{Now()} cyro-udp failed: {ex}");
        }
    }

    private void ProcessPacket(UdpClient udp, byte[] buffer, IPEndPoint remoteEndPoint)
    {
        var text = Encoding.UTF8.GetString(buffer).Trim();
        var message = CyrodiilProtocol.ParseMessage(buffer);
        if (message is null)
        {
            Console.WriteLine($"{Now()} cyro-udp invalid endpoint={remoteEndPoint} text=\"{text}\"");
            return;
        }

        Console.WriteLine($"{Now()} cyro-udp packet endpoint={remoteEndPoint} text=\"{text}\"");

        if (message.Verb.Equals("hello", StringComparison.OrdinalIgnoreCase))
        {
            var client = GetOrCreateClient(remoteEndPoint, message.Get("name", "unknown"));
            client.LastSeen = DateTimeOffset.UtcNow;
            client.Name = message.Get("name", client.Name);

            var response = FormatInvariant(
                $"server-welcome protocol={CyrodiilProtocol.ProtocolVersion} player={client.PlayerId} tick_rate={CyrodiilProtocol.DefaultServerTickRate}");
            SendText(udp, remoteEndPoint, response);
            Console.WriteLine($"{Now()} cyro-udp welcome player={client.PlayerId} name={client.Name} endpoint={remoteEndPoint}");
            return;
        }

        if (!clients.TryGetValue(remoteEndPoint, out var sender))
        {
            sender = GetOrCreateClient(remoteEndPoint, message.Get("name", "unknown"));
        }

        sender.LastSeen = DateTimeOffset.UtcNow;

        if (message.Verb.Equals("transform", StringComparison.OrdinalIgnoreCase))
        {
            sender.Name = message.Get("name", sender.Name);
            sender.LatestTransform = new TransformState(
                Tick: message.GetInt("tick", 0),
                X: GetFloat(message, "x"),
                Y: GetFloat(message, "y"),
                Z: GetFloat(message, "z"),
                Yaw: GetFloat(message, "yaw"));

            var outbound = FormatInvariant(
                $"remote-transform player={sender.PlayerId} name={Escape(sender.Name)} tick={sender.LatestTransform.Tick} x={sender.LatestTransform.X:0.00} y={sender.LatestTransform.Y:0.00} z={sender.LatestTransform.Z:0.00} yaw={sender.LatestTransform.Yaw:0.00}");
            BroadcastExcept(udp, sender.EndPoint, outbound);
            return;
        }

        if (message.Verb.Equals("disconnect", StringComparison.OrdinalIgnoreCase))
        {
            clients.Remove(remoteEndPoint);
            BroadcastExcept(udp, remoteEndPoint, $"player-left player={sender.PlayerId} reason=disconnect");
            Console.WriteLine($"{Now()} cyro-udp disconnect player={sender.PlayerId} endpoint={remoteEndPoint}");
        }
    }

    private ClientState GetOrCreateClient(IPEndPoint endPoint, string name)
    {
        if (clients.TryGetValue(endPoint, out var client))
        {
            return client;
        }

        client = new ClientState(endPoint, Interlocked.Increment(ref nextPlayerId), name, DateTimeOffset.UtcNow);
        clients[endPoint] = client;
        return client;
    }

    private void PruneTimedOutClients(UdpClient udp)
    {
        var now = DateTimeOffset.UtcNow;
        var timedOut = clients.Values
            .Where(client => now - client.LastSeen > ClientTimeout)
            .ToArray();

        foreach (var client in timedOut)
        {
            clients.Remove(client.EndPoint);
            BroadcastExcept(udp, client.EndPoint, $"player-left player={client.PlayerId} reason=timeout");
            Console.WriteLine($"{Now()} cyro-udp timeout player={client.PlayerId} endpoint={client.EndPoint}");
        }
    }

    private void BroadcastExcept(UdpClient udp, IPEndPoint except, string text)
    {
        foreach (var client in clients.Values)
        {
            if (client.EndPoint.Equals(except))
            {
                continue;
            }

            SendText(udp, client.EndPoint, text);
        }
    }

    private static void SendText(UdpClient udp, IPEndPoint endPoint, string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        udp.Send(bytes, bytes.Length, endPoint);
    }

    private static float GetFloat(CyrodiilMessage message, string name)
    {
        return float.TryParse(message.Get(name), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : 0.0f;
    }

    private static string Escape(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "unknown";
        }

        return value.Trim()
            .Replace('\\', '/')
            .Replace('"', '\'')
            .Replace('\r', ' ')
            .Replace('\n', ' ')
            .Replace(' ', '_');
    }

    private static string FormatInvariant(FormattableString value)
    {
        return value.ToString(CultureInfo.InvariantCulture);
    }

    private static string Now() => DateTimeOffset.Now.ToString("HH:mm:ss.fff", CultureInfo.InvariantCulture);

    private sealed class ClientState
    {
        public ClientState(IPEndPoint endPoint, int playerId, string name, DateTimeOffset lastSeen)
        {
            EndPoint = endPoint;
            PlayerId = playerId;
            Name = name;
            LastSeen = lastSeen;
        }

        public IPEndPoint EndPoint { get; }
        public int PlayerId { get; }
        public string Name { get; set; }
        public DateTimeOffset LastSeen { get; set; }
        public TransformState? LatestTransform { get; set; }
    }

    private sealed record TransformState(int Tick, float X, float Y, float Z, float Yaw);
}
