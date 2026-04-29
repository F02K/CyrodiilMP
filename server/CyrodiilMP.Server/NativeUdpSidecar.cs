using System.Net;
using System.Net.Sockets;
using System.Text;

namespace CyrodiilMP.Server;

sealed class NativeUdpSidecar
{
    private readonly int port;
    private readonly CancellationTokenSource stop = new();
    private Task? task;

    public NativeUdpSidecar(int port)
    {
        this.port = port;
    }

    public void Start()
    {
        task = Task.Run(RunAsync);
    }

    public async Task StopAsync()
    {
        stop.Cancel();
        if (task is not null)
        {
            try
            {
                await task;
            }
            catch (OperationCanceledException)
            {
            }
        }
    }

    private async Task RunAsync()
    {
        using var udp = new UdpClient(new IPEndPoint(IPAddress.Any, port));
        Console.WriteLine($"{Now()} native-udp listening on UDP port {port}");

        while (!stop.IsCancellationRequested)
        {
            UdpReceiveResult received;
            try
            {
                received = await udp.ReceiveAsync(stop.Token);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            var text = Encoding.UTF8.GetString(received.Buffer).Trim();
            Console.WriteLine($"{Now()} native-udp packet endpoint={received.RemoteEndPoint} text=\"{text}\"");

            var response = Encoding.UTF8.GetBytes("native-welcome status=ok protocol=0");
            var sent = await udp.SendAsync(response, received.RemoteEndPoint, stop.Token);
            Console.WriteLine($"{Now()} native-udp response endpoint={received.RemoteEndPoint} bytes={sent}");
        }
    }

    private static string Now() => DateTimeOffset.Now.ToString("HH:mm:ss.fff");
}
