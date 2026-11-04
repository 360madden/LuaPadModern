namespace LuaPadModern.HostCore;

// Immutable observations. No Win32 API calls, focus changes or simulated input.
public sealed record WindowIdentity(int ProcessId, long ProcessStartUtcTicks, long Hwnd);
public readonly record struct ClientBounds(int Left, int Top, int Width, int Height)
{
    public bool IsUsable => Width > 0 && Height > 0;
}
public sealed record WindowObservation(
    WindowIdentity Identity, ClientBounds Client,
    bool IsForeground, bool IsMinimized, DateTimeOffset MeasuredAtUtc);
public sealed record EditorEvidence(
    bool? AddonWindowVisible,
    bool? AddonEditorKeyFocus,
    bool? HostScreenshotOcclusionClear,
    DateTimeOffset CapturedAtUtc);

// The Windows controller must measure *again* just before using any coordinates.
public static class HostReadinessGate
{
    public static string CheckWindow(
        WindowIdentity? expected,
        WindowObservation? whenPlanned,
        WindowObservation? immediatelyBeforeAction,
        DateTimeOffset nowUtc,
        TimeSpan maximumEvidenceAge)
    {
        if (expected is null || expected.ProcessId <= 0 || expected.ProcessStartUtcTicks <= 0
            || expected.Hwnd == 0 || whenPlanned is null || immediatelyBeforeAction is null)
            return "TARGET_UNAVAILABLE";
        if (whenPlanned.Identity != expected || immediatelyBeforeAction.Identity != expected)
            return "TARGET_CHANGED";
        if (!immediatelyBeforeAction.IsForeground) return "WINDOW_NOT_FOREGROUND";
        if (immediatelyBeforeAction.IsMinimized || !immediatelyBeforeAction.Client.IsUsable)
            return "TARGET_UNAVAILABLE";
        if (whenPlanned.Client != immediatelyBeforeAction.Client)
            return "CLIENT_BOUNDS_CHANGED";
        if (!Fresh(whenPlanned.MeasuredAtUtc, nowUtc, maximumEvidenceAge)
            || !Fresh(immediatelyBeforeAction.MeasuredAtUtc, nowUtc, maximumEvidenceAge)
            || immediatelyBeforeAction.MeasuredAtUtc < whenPlanned.MeasuredAtUtc)
            return "UI_UNVERIFIED";
        return "OK";
    }

    public static string CheckEditorInput(
        WindowIdentity? expected,
        WindowObservation? whenPlanned,
        WindowObservation? immediatelyBeforeAction,
        EditorEvidence? uiEvidence,
        DateTimeOffset nowUtc,
        TimeSpan maximumEvidenceAge)
    {
        var windowStatus = CheckWindow(
            expected, whenPlanned, immediatelyBeforeAction, nowUtc, maximumEvidenceAge);
        if (windowStatus != "OK") return windowStatus;
        if (uiEvidence is null || !Fresh(uiEvidence.CapturedAtUtc, nowUtc, maximumEvidenceAge))
            return "UI_UNVERIFIED";
        if (uiEvidence.AddonWindowVisible != true) return "LUAPAD_NOT_VISIBLE";
        if (uiEvidence.AddonEditorKeyFocus != true) return "EDITOR_NOT_FOCUSED";
        // This is a host screenshot finding, not something ui.status can attest.
        if (uiEvidence.HostScreenshotOcclusionClear != true) return "LUAPAD_OCCLUDED";
        return "OK";
    }

    private static bool Fresh(DateTimeOffset observed, DateTimeOffset now, TimeSpan maximumAge)
        => maximumAge > TimeSpan.Zero && observed <= now
            && now - observed <= maximumAge;
}
