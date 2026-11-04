using LuaPadModern.HostCore;

internal static class Program
{
    private const string Healthy = """
        {"protocol":"luapad-bridge","version":1,"kind":"result","requestId":"req-20261104-0001","sessionId":"winhost-session-20261104","operation":"health","source":{"component":"addon","addonVersion":"2.0.0-preview17"},"payload":{"routerReady":true,"liveTransportReady":false},"status":"ok","meta":{"truncated":false}}
        """;
    private static readonly ExpectedResult Expected =
        new("req-20261104-0001", "winhost-session-20261104", "health");
    private const string PreviousClipboard = "clipboard-before-command";
    private static int _passed;

    private static void Check(string label, bool condition)
    {
        if (!condition) throw new InvalidOperationException("FAIL " + label);
        _passed++;
        Console.WriteLine("PASS " + label);
    }
    private static void Code(string label, string? json, string expectedCode,
        string? before = PreviousClipboard, ExpectedResult? identity = null)
    {
        var response = BridgeResultValidator.Validate(json, before, identity ?? Expected);
        Check(label, !response.Accepted && response.Code == expectedCode);
    }
    private static string Replace(string before, string after) =>
        Healthy.Replace(before, after, StringComparison.Ordinal);
    private static void Accept(string label, string value, string status = "ok")
    {
        var result = BridgeResultValidator.Validate(value, PreviousClipboard, Expected);
        Check(label, result.Accepted && result.Code == "OK" && result.Status == status);
    }

    public static void Main()
    {
        var valid = BridgeResultValidator.Validate(Healthy, PreviousClipboard, Expected);
        Check("valid read-only health reply accepted", valid.Accepted);
        Check("accepted code", valid.Code == "OK");
        Check("result status", valid.Status == "ok");
        Check("UTF-8 byte count", valid.Utf8Bytes == System.Text.Encoding.UTF8.GetByteCount(Healthy));
        Accept("partial result accepted", Replace("\"status\":\"ok\"", "\"status\":\"partial\""), "partial");
        Accept("valid structured error delivered", Replace("\"status\":\"ok\"",
            "\"status\":\"error\",\"error\":{\"code\":\"GAME_NOT_READY\",\"message\":\"No frame\"}"), "error");
        Accept("error details object accepted", Replace("\"status\":\"ok\"",
            "\"status\":\"error\",\"error\":{\"code\":\"GAME_NOT_READY\",\"message\":\"No frame\",\"details\":{}}"), "error");
        Accept("metadata truncated true accepted", Replace("\"truncated\":false", "\"truncated\":true"));
        Accept("declared transport typed but not trusted", Replace("\"truncated\":false",
            "\"truncated\":false,\"transport\":\"clipboard\""));
        Accept("host timestamp string field accepted", Replace("\"truncated\":false",
            "\"truncated\":false,\"receivedAtUtc\":\"2026-11-04T12:00:00Z\""));
        Accept("valid evidence SHA256 accepted", Replace("\"truncated\":false",
            "\"truncated\":false,\"evidenceSha256\":\"" + new string('a', 64) + "\""));
        Code("malformed timestamp rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"receivedAtUtc\":\"not-a-date\""), "INVALID_ENVELOPE");
        Code("short evidence hash rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"evidenceSha256\":\"ab12\""), "INVALID_ENVELOPE");
        Code("uppercase evidence hash rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"evidenceSha256\":\"" + new string('A', 64) + "\""),
            "INVALID_ENVELOPE");

        Code("stale same-bytes clipboard rejected", Healthy, "CLIPBOARD_STALE", Healthy);
        Code("missing pre-dispatch clipboard rejected", Healthy, "BASELINE_MISSING", null);
        Code("empty clipboard rejected", "", "CLIPBOARD_EMPTY");
        Code("whitespace clipboard rejected", "  \t ", "CLIPBOARD_EMPTY");
        Code("null clipboard rejected", null, "CLIPBOARD_EMPTY");
        Code("missing expected identity rejected", Healthy, "EXPECTATION_MISSING",
            PreviousClipboard, new ExpectedResult("", "winhost-session-20261104", "health"));
        Check("null expected identity rejected",
            BridgeResultValidator.Validate(Healthy, PreviousClipboard, null).Code == "EXPECTATION_MISSING");
        Code("mismatched request ID rejected", Replace("req-20261104-0001", "req-20261104-old1"),
            "RESULT_MISMATCH");
        Code("mismatched session rejected", Replace("winhost-session-20261104", "oldhost-session-20261104"),
            "RESULT_MISMATCH");
        Code("mismatched operation rejected", Replace("\"operation\":\"health\"", "\"operation\":\"ui.status\""),
            "RESULT_MISMATCH");
        Code("wrong protocol rejected", Replace("luapad-bridge", "other-bridge"), "INVALID_ENVELOPE");
        Code("wrong version rejected", Replace("\"version\":1", "\"version\":2"), "INVALID_ENVELOPE");
        Code("non-result kind rejected", Replace("\"kind\":\"result\"", "\"kind\":\"request\""), "INVALID_ENVELOPE");
        Code("source spoofed as host rejected", Replace("\"component\":\"addon\"", "\"component\":\"host\""),
            "INVALID_ENVELOPE");
        Code("missing source rejected", Replace("\"source\":{\"component\":\"addon\",\"addonVersion\":\"2.0.0-preview17\"},", ""),
            "INVALID_ENVELOPE");
        Code("payload not an object rejected", Replace("\"payload\":{\"routerReady\":true,\"liveTransportReady\":false}",
            "\"payload\":[]"), "INVALID_ENVELOPE");
        Code("missing metadata rejected", Replace(",\"meta\":{\"truncated\":false}", ""), "INVALID_ENVELOPE");
        Code("missing truncation flag rejected", Replace("\"meta\":{\"truncated\":false}", "\"meta\":{}"),
            "INVALID_ENVELOPE");
        Code("wrong truncation flag type rejected", Replace("\"truncated\":false", "\"truncated\":\"false\""),
            "INVALID_ENVELOPE");
        Code("invalid status rejected", Replace("\"status\":\"ok\"", "\"status\":\"done\""), "INVALID_ENVELOPE");
        Code("error status missing error object rejected", Replace("\"status\":\"ok\"", "\"status\":\"error\""),
            "INVALID_ENVELOPE");
        Code("error field with success rejected", Replace("\"status\":\"ok\"",
            "\"status\":\"ok\",\"error\":{\"code\":\"ERR\",\"message\":\"oops\"}"), "INVALID_ENVELOPE");
        Code("invalid error code rejected", Replace("\"status\":\"ok\"",
            "\"status\":\"error\",\"error\":{\"code\":\"bad\",\"message\":\"oops\"}"), "INVALID_ENVELOPE");
        Code("empty error message rejected", Replace("\"status\":\"ok\"",
            "\"status\":\"error\",\"error\":{\"code\":\"ERR\",\"message\":\"\"}"), "INVALID_ENVELOPE");
        Code("unknown envelope field rejected", Replace("\"status\":\"ok\"", "\"status\":\"ok\",\"extra\":true"),
            "INVALID_ENVELOPE");
        Code("unknown source field rejected", Replace("\"component\":\"addon\"",
            "\"component\":\"addon\",\"elevated\":true"), "INVALID_ENVELOPE");
        Code("unknown metadata field rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"secret\":true"), "INVALID_ENVELOPE");
        Code("invalid source version type rejected", Replace("\"addonVersion\":\"2.0.0-preview17\"",
            "\"addonVersion\":4"), "INVALID_ENVELOPE");
        Code("invalid transport name rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"transport\":\"magic\""), "INVALID_ENVELOPE");
        Code("negative source age rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"sourceAgeMs\":-1"), "INVALID_ENVELOPE");
        Code("zero chunk total rejected", Replace("\"truncated\":false",
            "\"truncated\":false,\"chunkTotal\":0"), "INVALID_ENVELOPE");
        Code("top-level duplicate keys rejected", Replace("\"status\":\"ok\"",
            "\"status\":\"ok\",\"status\":\"error\""), "INVALID_ENVELOPE");
        Code("nested duplicate keys rejected", Replace("\"routerReady\":true",
            "\"routerReady\":true,\"routerReady\":false"), "INVALID_ENVELOPE");
        Code("array root rejected", "[]", "INVALID_ENVELOPE");
        Code("trailing junk rejected", Healthy + " extra", "INVALID_JSON");
        Code("trailing comma rejected", Healthy[..^1] + ",}", "INVALID_JSON");
        Code("broken JSON rejected", "{\"protocol\":", "INVALID_JSON");
        Code("overlong result rejected", Healthy + new string('x', 16400), "RESULT_TOO_LARGE");
        Code("unpaired surrogate rejected", Healthy + "\ud800", "INVALID_UTF8");
        Code("excessive nesting rejected", "{\"a\":" + new string('[', 18) + "0" +
            new string(']', 18) + "}", "INVALID_JSON");

        var now = DateTimeOffset.UtcNow;
        var age = TimeSpan.FromSeconds(1);
        var identity = new WindowIdentity(333, 638978544000000000L, 0x1234);
        var bounds = new ClientBounds(100, 120, 1280, 720);
        var planned = new WindowObservation(identity, bounds, true, false, now.AddMilliseconds(-250));
        var fresh = planned with { MeasuredAtUtc = now.AddMilliseconds(-50) };
        var evidence = new EditorEvidence(true, true, true, now.AddMilliseconds(-40));
        string Window(WindowIdentity? pin, WindowObservation? initial, WindowObservation? recent) =>
            HostReadinessGate.CheckWindow(pin, initial, recent, now, age);
        string Editor(WindowObservation? recent, EditorEvidence? observation) =>
            HostReadinessGate.CheckEditorInput(identity, planned, recent, observation, now, age);

        Check("fresh matching target accepted", Window(identity, planned, fresh) == "OK");
        Check("editor ready when all independent gates pass", Editor(fresh, evidence) == "OK");
        Check("missing binding refused", Window(null, planned, fresh) == "TARGET_UNAVAILABLE");
        Check("missing planned observation refused", Window(identity, null, fresh) == "TARGET_UNAVAILABLE");
        Check("missing fresh observation refused", Window(identity, planned, null) == "TARGET_UNAVAILABLE");
        Check("changed PID refused", Window(identity, planned, fresh with {
            Identity = identity with { ProcessId = 777 }}) == "TARGET_CHANGED");
        Check("changed process start refused", Window(identity, planned, fresh with {
            Identity = identity with { ProcessStartUtcTicks = identity.ProcessStartUtcTicks + 1 }}) == "TARGET_CHANGED");
        Check("changed HWND refused", Window(identity, planned, fresh with {
            Identity = identity with { Hwnd = 0x3456 }}) == "TARGET_CHANGED");
        Check("window foreground required", Window(identity, planned, fresh with {
            IsForeground = false }) == "WINDOW_NOT_FOREGROUND");
        Check("minimized window refused", Window(identity, planned, fresh with {
            IsMinimized = true }) == "TARGET_UNAVAILABLE");
        Check("zero width refused", Window(identity, planned, fresh with {
            Client = bounds with { Width = 0 }}) == "TARGET_UNAVAILABLE");
        Check("resized window refused before any click", Window(identity, planned, fresh with {
            Client = bounds with { Width = 1920 }}) == "CLIENT_BOUNDS_CHANGED");
        Check("moved window refused before any click", Window(identity, planned, fresh with {
            Client = bounds with { Left = 500 }}) == "CLIENT_BOUNDS_CHANGED");
        Check("stale planned bounds refused", Window(identity, planned with {
            MeasuredAtUtc = now.AddSeconds(-3) }, fresh) == "UI_UNVERIFIED");
        Check("stale latest bounds refused", Window(identity, planned, fresh with {
            MeasuredAtUtc = now.AddSeconds(-3) }) == "UI_UNVERIFIED");
        Check("future timestamp refused", Window(identity, planned, fresh with {
            MeasuredAtUtc = now.AddSeconds(1) }) == "UI_UNVERIFIED");
        Check("reordered snapshots refused", Window(identity, planned, fresh with {
            MeasuredAtUtc = now.AddMilliseconds(-500) }) == "UI_UNVERIFIED");
        Check("nonpositive evidence age refused", HostReadinessGate.CheckWindow(
            identity, planned, fresh, now, TimeSpan.Zero) == "UI_UNVERIFIED");

        Check("editor evidence required", Editor(fresh, null) == "UI_UNVERIFIED");
        Check("stale editor evidence refused", Editor(fresh, evidence with {
            CapturedAtUtc = now.AddSeconds(-3) }) == "UI_UNVERIFIED");
        Check("hidden addon refused", Editor(fresh, evidence with {
            AddonWindowVisible = false }) == "LUAPAD_NOT_VISIBLE");
        Check("missing addon visibility refused", Editor(fresh, evidence with {
            AddonWindowVisible = null }) == "LUAPAD_NOT_VISIBLE");
        Check("editor not focused refused", Editor(fresh, evidence with {
            AddonEditorKeyFocus = false }) == "EDITOR_NOT_FOCUSED");
        Check("unknown key focus refused", Editor(fresh, evidence with {
            AddonEditorKeyFocus = null }) == "EDITOR_NOT_FOCUSED");
        Check("occluded addon refused", Editor(fresh, evidence with {
            HostScreenshotOcclusionClear = false }) == "LUAPAD_OCCLUDED");
        Check("unknown occlusion refused", Editor(fresh, evidence with {
            HostScreenshotOcclusionClear = null }) == "LUAPAD_OCCLUDED");
        Check("editor gate inherits foreground refusal", Editor(fresh with {
            IsForeground = false }, evidence) == "WINDOW_NOT_FOREGROUND");
        Check("editor gate inherits resize refusal", Editor(fresh with {
            Client = bounds with { Height = 1080 } }, evidence) == "CLIENT_BOUNDS_CHANGED");

        LogTailTests.Run(Check);
        Console.WriteLine($"HostCore source-only checks: {_passed} passed");
    }
}
