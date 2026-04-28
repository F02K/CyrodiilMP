using System.Text;

namespace CyrodiilMP.Protocol;

public static class CyrodiilProtocol
{
    public const string ConnectionKey = "CyrodiilMP";
    public const int DefaultPort = 27015;
    public const string DefaultHost = "127.0.0.1";

    public static byte[] CreateHello(string name, string source)
    {
        return Utf8($"hello name={Escape(name)} source={Escape(source)} protocol=0");
    }

    public static byte[] CreateMenuConnectRequest(string name, string reason)
    {
        return Utf8($"menu-connect name={Escape(name)} reason={Escape(reason)}");
    }

    public static byte[] CreateTransform(
        string name,
        int tick,
        float x,
        float y,
        float z,
        float yaw)
    {
        return Utf8(FormattableString.Invariant(
            $"transform name={Escape(name)} tick={tick} x={x:0.00} y={y:0.00} z={z:0.00} yaw={yaw:0.00}"));
    }

    public static string DecodePreview(ReadOnlySpan<byte> payload)
    {
        if (payload.IsEmpty)
        {
            return "";
        }

        try
        {
            var text = Encoding.UTF8.GetString(payload);
            return text.ReplaceLineEndings(" ").Trim();
        }
        catch (DecoderFallbackException)
        {
            return Convert.ToHexString(payload);
        }
    }

    private static byte[] Utf8(string value) => Encoding.UTF8.GetBytes(value);

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
}
