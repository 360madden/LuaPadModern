using System.Text;
using LuaPadModern.HostCore;

internal static class LogTailTests
{
    private const string Nonce = "LPB_HOST_20261104_TEST";
    private const string Marker = "LPB_PROBE|" + Nonce + "|";
    private static readonly Encoding Utf8 = new UTF8Encoding(false);

    public static void Run(Action<string, bool> check)
    {
        var root = Directory.CreateTempSubdirectory("LuaPadModern-logtail-");
        try
        {
            string NewPath(string name)
            {
                var folder = Path.Combine(root.FullName, name);
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "Log.txt");
            }
            static bool Throws<T>(Action body) where T : Exception
            {
                try { body(); return false; }
                catch (T) { return true; }
            }

            var missing = NewPath("creation");
            using (var tail = new NoncombatLogTailer(missing, Nonce))
            {
                check("log is absent without a game command", tail.Poll().Status == "WAITING_FOR_FILE");
                File.WriteAllText(missing, "unrelated chat line\n", Utf8);
                check("new log detected without a UI reload", tail.Poll().Status == "WATCHING");
                File.AppendAllText(missing, "LPB_PROBE|WRONG_TOKEN|1700000000\n", Utf8);
                check("wrong nonce ignored", tail.Poll().Status == "WATCHING");
                File.AppendAllText(missing, Marker + "1700000000.125", Utf8);
                check("split line withheld until newline", tail.Poll().Status == "WATCHING");
                File.AppendAllText(missing, "\n", Utf8);
                var result = tail.Poll(DateTimeOffset.FromUnixTimeMilliseconds(1_700_000_000_500));
                check("created-file marker detected", result.Status == "MATCHED" && result.Match is not null);
                check("exact nonce is retained", result.Match?.Nonce == Nonce);
                check("valid server epoch parsed", result.Match?.ServerEpochSeconds == 1_700_000_000.125);
                check("server/host clock delta labeled", result.Match?.ServerClockDeltaMs == 375);
                check("clock delta explicitly not flush latency", result.Match?.IsFlushLatencyMeasurement == false);
                check("repeat polls do not duplicate receipt", ReferenceEquals(tail.Poll().Match, result.Match));
                check("unrelated chat never exposed", !result.ToString()!.Contains("unrelated chat", StringComparison.Ordinal));
            }

            var history = NewPath("existing-history");
            File.WriteAllText(history, Marker + "1700000001\n", Utf8);
            using (var tail = new NoncombatLogTailer(history, Nonce))
            {
                check("existing history skipped", tail.Poll().Status == "WATCHING");
                File.AppendAllText(history, Marker + "1700000002\n", Utf8);
                check("fresh append observed on existing file",
                    tail.Poll().Match?.ServerEpochSeconds == 1_700_000_002);
            }
            using (var tail = new NoncombatLogTailer(history, Nonce, fromStart: true))
                check("explicit fromStart reads history", tail.Poll().Status == "MATCHED");

            var noEpoch = NewPath("no-epoch");
            File.WriteAllText(noEpoch, Marker + "unknown\n", Utf8);
            using (var tail = new NoncombatLogTailer(noEpoch, Nonce, fromStart: true))
                check("unknown epoch accepted without fake timing",
                    tail.Poll().Match is { ServerEpochSeconds: null, ServerClockDeltaMs: null });

            var utf16 = NewPath("utf16");
            var raw = Encoding.Unicode.GetPreamble()
                .Concat(Encoding.Unicode.GetBytes("RIFT chat\r\n" + Marker + "1700000003.5\r\n")).ToArray();
            File.WriteAllBytes(utf16, raw[..^1]);
            using (var tail = new NoncombatLogTailer(utf16, Nonce, fromStart: true, maximumBytesPerPoll: 5))
            {
                for (var i = 0; i < raw.Length / 5 + 3; i++)
                    tail.Poll();
                check("UTF-16 missing final code unit stays incomplete", tail.Poll().Status == "WATCHING");
                using (var output = new FileStream(utf16, FileMode.Append, FileAccess.Write, FileShare.ReadWrite))
                    output.WriteByte(raw[^1]);
                NoncombatLogPoll final = new("WATCHING");
                for (var i = 0; i < 6; i++) final = tail.Poll();
                check("UTF-16LE BOM and split character recognized",
                    final.Match?.ServerEpochSeconds == 1_700_000_003.5);
            }

            var utf8 = NewPath("unicode");
            File.WriteAllText(utf8, "☕" + Marker + "1700000004\n", Utf8);
            using (var tail = new NoncombatLogTailer(utf8, Nonce, fromStart: true, maximumBytesPerPoll: 3))
            {
                NoncombatLogPoll result = new("WATCHING");
                for (var i = 0; i < 90 && result.Match is null; i++) result = tail.Poll();
                check("UTF-8 multi-byte boundary survives bounded reads",
                    result.Match?.ServerEpochSeconds == 1_700_000_004);
            }

            var rotated = NewPath("rotation");
            File.WriteAllText(rotated, "initial log\n", Utf8);
            using (var tail = new NoncombatLogTailer(rotated, Nonce))
            {
                check("rotation fixture initial file watched", tail.Poll().Status == "WATCHING");
                File.AppendAllText(rotated, Marker + "1700000005", Utf8);
                check("rotation fixture partial line saved", tail.Poll().Status == "WATCHING");
                File.Move(rotated, rotated + ".old");
                File.WriteAllText(rotated, Marker + "1700000006\n", Utf8);
                File.SetCreationTimeUtc(rotated, DateTime.UtcNow.AddDays(-1));
                check("replaced file drops partial old marker", tail.Poll().Match?.ServerEpochSeconds == 1_700_000_006);
            }

            var truncated = NewPath("truncation");
            File.WriteAllText(truncated, new string('x', 512), Utf8);
            using (var tail = new NoncombatLogTailer(truncated, Nonce))
            {
                check("truncation fixture at EOF", tail.Poll().Status == "WATCHING");
                File.WriteAllText(truncated, Marker + "1700000007\n", Utf8);
                check("truncated file read from new beginning", tail.Poll().Match?.ServerEpochSeconds == 1_700_000_007);
            }

            var oversized = NewPath("huge-line");
            File.WriteAllText(oversized, new string('x', 40_000) + Marker + "unknown\n", Utf8);
            using (var tail = new NoncombatLogTailer(oversized, Nonce, fromStart: true))
            {
                check("bounded long-line tail matches its valid suffix", tail.Poll().Status == "MATCHED");
                check("long-line receipt contains no raw text",
                    tail.Poll().Match?.ToString().Contains("xxxx", StringComparison.Ordinal) == false);
            }

            var noPrefix = NewPath("no-prefix");
            File.WriteAllText(noPrefix, "LPB_OTHER|" + Nonce + "|1700000000\n", Utf8);
            using (var tail = new NoncombatLogTailer(noPrefix, Nonce, fromStart: true))
                check("only correct probe prefix matches", tail.Poll().Status == "WATCHING");

            check("relative log path rejected", Throws<ArgumentException>(() =>
                new NoncombatLogTailer("relative-log.txt", Nonce)));
            check("short nonce rejected", Throws<ArgumentException>(() =>
                new NoncombatLogTailer(history, "short")));
            check("zero read budget rejected", Throws<ArgumentOutOfRangeException>(() =>
                new NoncombatLogTailer(history, Nonce, maximumBytesPerPoll: 0)));
            check("oversized read budget rejected", Throws<ArgumentOutOfRangeException>(() =>
                new NoncombatLogTailer(history, Nonce, maximumBytesPerPoll: 300_000)));
            var disposed = new NoncombatLogTailer(history, Nonce);
            disposed.Dispose();
            check("disposed reader rejects further polling", Throws<ObjectDisposedException>(() => disposed.Poll()));
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }
}
