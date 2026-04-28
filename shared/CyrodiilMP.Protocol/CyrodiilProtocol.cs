using System.Collections.Generic;
using System.Text;

namespace CyrodiilMP.Protocol;

public static class CyrodiilProtocol
{
    public const string ConnectionKey = "CyrodiilMP";
    public const int DefaultPort = 27015;
    public const string DefaultHost = "127.0.0.1";
    public const int ProtocolVersion = 0;
    public const int DefaultServerTickRate = 15;

    public static byte[] CreateHello(string name, string source)
    {
        return Utf8($"hello name={Escape(name)} source={Escape(source)} protocol={ProtocolVersion}");
    }

    public static byte[] CreateMenuConnectRequest(string name, string reason)
    {
        return Utf8($"menu-connect name={Escape(name)} reason={Escape(reason)}");
    }

    public static byte[] CreateServerWelcome(int playerId, string serverName)
    {
        return Utf8($"server-welcome player_id={playerId} server_name={Escape(serverName)} protocol=0");
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

    public static byte[] CreateServerWelcome(int playerId, int tickRate)
    {
        return Utf8($"server-welcome player={playerId} tick_rate={tickRate} protocol={ProtocolVersion}");
    }

    public static byte[] CreateMenuConnectAck(int playerId, string status)
    {
        return Utf8($"menu-connect-ack player={playerId} status={Escape(status)}");
    }

    public static CyrodiilMessage? ParseMessage(ReadOnlySpan<byte> payload)
    {
        if (payload.IsEmpty)
        {
            return null;
        }

        string text;
        try
        {
            text = Encoding.UTF8.GetString(payload);
        }
        catch (DecoderFallbackException)
        {
            return null;
        }

        text = text.Trim();
        if (text.Length == 0)
        {
            return null;
        }

        var parts = text.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0)
        {
            return null;
        }

        var fields = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 1; i < parts.Length; i++)
        {
            var token = parts[i];
            var equalsIndex = token.IndexOf('=');
            if (equalsIndex <= 0 || equalsIndex == token.Length - 1)
            {
                continue;
            }

            var key = token[..equalsIndex];
            var value = token[(equalsIndex + 1)..];
            fields[key] = value;
        }

        return new CyrodiilMessage(parts[0], fields, text);
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

public sealed record CyrodiilMessage(
    string Verb,
    IReadOnlyDictionary<string, string> Fields,
    string RawText)
{
    public string Get(string name, string fallback = "")
    {
        return Fields.TryGetValue(name, out var value) ? value : fallback;
    }

    public int GetInt(string name, int fallback = 0)
    {
        return Fields.TryGetValue(name, out var value) && int.TryParse(value, out var parsed)
            ? parsed
            : fallback;
    }
}
