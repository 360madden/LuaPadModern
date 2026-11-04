using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace LuaPadModern.HostCore;

public sealed record ExpectedResult(string RequestId, string SessionId, string Operation);

public sealed record BridgeValidation(bool Accepted, string Code, string? Status = null, int Utf8Bytes = 0)
{
    public static BridgeValidation Reject(string code) => new(false, code);
}

// Pure host-side boundary: no clipboard, keyboard, HWND or network access.
// The caller must independently prove that its clipboard snapshot followed dispatch.
public static class BridgeResultValidator
{
    public const int MaximumResultBytes = 16_384;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    private static readonly HashSet<string> TopKeys = new(StringComparer.Ordinal)
    {
        "protocol", "version", "kind", "requestId", "sessionId", "operation",
        "source", "payload", "status", "meta", "error"
    };
    private static readonly HashSet<string> SourceKeys = new(StringComparer.Ordinal)
    {
        "component", "addonVersion", "clientTag"
    };
    private static readonly HashSet<string> MetaKeys = new(StringComparer.Ordinal)
    {
        "truncated", "transport", "receivedAtUtc", "evidenceSha256",
        "sourceAgeMs", "chunkIndex", "chunkTotal"
    };
    private static readonly HashSet<string> ErrorKeys = new(StringComparer.Ordinal)
    {
        "code", "message", "details"
    };
    private static readonly HashSet<string> TransportNames = new(StringComparer.Ordinal)
    {
        "clipboard", "win32-input", "uia", "ipc", "rr2"
    };
    private static readonly Regex ErrorCode = new(
        @"\A[A-Z][A-Z0-9_]{2,63}\z", RegexOptions.CultureInvariant);
    private static readonly Regex UtcTimestamp = new(
        @"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z\z",
        RegexOptions.CultureInvariant);
    private static readonly Regex Sha256 = new(
        @"\A[a-f0-9]{64}\z", RegexOptions.CultureInvariant);

    public static BridgeValidation Validate(
        string? afterDispatch, string? beforeDispatch, ExpectedResult? expected)
    {
        if (expected is null || string.IsNullOrEmpty(expected.RequestId)
            || string.IsNullOrEmpty(expected.SessionId)
            || string.IsNullOrEmpty(expected.Operation))
        {
            return BridgeValidation.Reject("EXPECTATION_MISSING");
        }
        if (beforeDispatch is null) return BridgeValidation.Reject("BASELINE_MISSING");
        if (string.IsNullOrWhiteSpace(afterDispatch))
            return BridgeValidation.Reject("CLIPBOARD_EMPTY");
        if (string.Equals(beforeDispatch, afterDispatch, StringComparison.Ordinal))
            return BridgeValidation.Reject("CLIPBOARD_STALE");

        int bytes;
        try { bytes = StrictUtf8.GetByteCount(afterDispatch); }
        catch (EncoderFallbackException) { return BridgeValidation.Reject("INVALID_UTF8"); }
        if (bytes > MaximumResultBytes)
            return BridgeValidation.Reject("RESULT_TOO_LARGE");

        try
        {
            using var json = JsonDocument.Parse(afterDispatch, new JsonDocumentOptions
            {
                MaxDepth = 16,
                AllowTrailingCommas = false,
                CommentHandling = JsonCommentHandling.Disallow
            });
            var root = json.RootElement;
            if (root.ValueKind != JsonValueKind.Object || HasDuplicateKeys(root)
                || !AllowedOnly(root, TopKeys)
                || !EqualsString(root, "protocol", "luapad-bridge")
                || !EqualsInt(root, "version", 1)
                || !EqualsString(root, "kind", "result"))
            {
                return BridgeValidation.Reject("INVALID_ENVELOPE");
            }
            if (!EqualsString(root, "requestId", expected.RequestId)
                || !EqualsString(root, "sessionId", expected.SessionId)
                || !EqualsString(root, "operation", expected.Operation))
            {
                return BridgeValidation.Reject("RESULT_MISMATCH");
            }
            if (!Object(root, "source", out var source)
                || !AllowedOnly(source, SourceKeys)
                || !EqualsString(source, "component", "addon")
                || !OptionalBoundedString(source, "addonVersion", 64)
                || !OptionalBoundedString(source, "clientTag", 128)
                || !Object(root, "payload", out _)
                || !Object(root, "meta", out var meta)
                || !AllowedOnly(meta, MetaKeys)
                || !Bool(meta, "truncated")
                || !OptionalEnum(meta, "transport", TransportNames)
                || !OptionalPattern(meta, "receivedAtUtc", UtcTimestamp, 64)
                || !OptionalPattern(meta, "evidenceSha256", Sha256, 64)
                || !OptionalNonnegativeInt(meta, "sourceAgeMs")
                || !OptionalNonnegativeInt(meta, "chunkIndex")
                || !OptionalNonnegativeInt(meta, "chunkTotal", 1))
            {
                return BridgeValidation.Reject("INVALID_ENVELOPE");
            }

            if (!String(root, "status", out var status)
                || (status != "ok" && status != "partial" && status != "error"))
                return BridgeValidation.Reject("INVALID_ENVELOPE");
            if (status == "error")
            {
                if (!Object(root, "error", out var error)
                    || !AllowedOnly(error, ErrorKeys)
                    || !String(error, "code", out var code)
                    || !ErrorCode.IsMatch(code)
                    || !String(error, "message", out var message)
                    || message.Length is < 1 or > 2048
                    || (error.TryGetProperty("details", out var details)
                        && details.ValueKind != JsonValueKind.Object))
                    return BridgeValidation.Reject("INVALID_ENVELOPE");
            }
            else if (root.TryGetProperty("error", out _))
            {
                return BridgeValidation.Reject("INVALID_ENVELOPE");
            }
            return new BridgeValidation(true, "OK", status, bytes);
        }
        catch (JsonException) { return BridgeValidation.Reject("INVALID_JSON"); }
        catch (ArgumentException) { return BridgeValidation.Reject("INVALID_JSON"); }
    }

    private static bool HasDuplicateKeys(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in element.EnumerateObject())
                if (!seen.Add(property.Name) || HasDuplicateKeys(property.Value)) return true;
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
                if (HasDuplicateKeys(item)) return true;
        }
        return false;
    }
    private static bool AllowedOnly(JsonElement obj, HashSet<string> allowed)
    {
        foreach (var property in obj.EnumerateObject())
            if (!allowed.Contains(property.Name)) return false;
        return true;
    }
    private static bool Object(JsonElement obj, string name, out JsonElement value)
        => obj.TryGetProperty(name, out value) && value.ValueKind == JsonValueKind.Object;
    private static bool String(JsonElement obj, string name, out string value)
    {
        value = "";
        if (!obj.TryGetProperty(name, out var field)
            || field.ValueKind != JsonValueKind.String) return false;
        value = field.GetString()!;
        return true;
    }
    private static bool EqualsString(JsonElement obj, string name, string expected)
        => String(obj, name, out var found) && found == expected;
    private static bool EqualsInt(JsonElement obj, string name, int expected)
        => obj.TryGetProperty(name, out var value)
            && value.ValueKind == JsonValueKind.Number
            && value.TryGetInt32(out var integer) && integer == expected;
    private static bool Bool(JsonElement obj, string name)
        => obj.TryGetProperty(name, out var value)
            && value.ValueKind is JsonValueKind.True or JsonValueKind.False;
    private static bool OptionalBoundedString(JsonElement obj, string name, int maximum)
        => !obj.TryGetProperty(name, out var value)
            || (value.ValueKind == JsonValueKind.String
                && value.GetString()!.Length <= maximum);
    private static bool OptionalPattern(
        JsonElement obj, string name, Regex pattern, int maximum)
        => !obj.TryGetProperty(name, out var value)
            || (value.ValueKind == JsonValueKind.String
                && value.GetString() is string text
                && text.Length <= maximum && pattern.IsMatch(text));
    private static bool OptionalEnum(JsonElement obj, string name, HashSet<string> allowed)
        => !obj.TryGetProperty(name, out var value)
            || (value.ValueKind == JsonValueKind.String
                && allowed.Contains(value.GetString()!));
    private static bool OptionalNonnegativeInt(JsonElement obj, string name, int minimum = 0)
        => !obj.TryGetProperty(name, out var value)
            || (value.ValueKind == JsonValueKind.Number
                && value.TryGetInt32(out var integer) && integer >= minimum);
}
