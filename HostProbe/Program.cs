using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using LuaPadModern.HostCore;

internal static class Program
{
    private const int DefaultTimeoutMs = 120_000;
    private const int DefaultPollMs = 100;

    private static void Write(object value) =>
        Console.WriteLine(JsonSerializer.Serialize(value));

    private static void Usage()
    {
        Console.WriteLine("LuaPadModern read-only RIFT Log.txt probe (.NET 10)");
        Console.WriteLine("  --nonce TOKEN [--path ABSOLUTE_LOG_FILE] [--timeout-ms 1000..300000]");
        Console.WriteLine("                [--poll-ms 25..1000]");
        Console.WriteLine("  --nonce TOKEN --print-lua   Print inert LuaPad marker code and exit.");
        Console.WriteLine("  --help                     Show this message.");
        Console.WriteLine("This program never focuses RIFT, sends game input or writes log files.");
    }

    private static string DefaultLogPath()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var roots = new[] { Environment.GetEnvironmentVariable("OneDrive"),
            Path.Combine(home, "OneDrive"), home };
        var candidates = roots.Where(root => !string.IsNullOrWhiteSpace(root))
            .Select(root => Path.Combine(root!, "Documents", "RIFT", "Log.txt"))
            .Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        return candidates.FirstOrDefault(File.Exists) ?? candidates[0];
    }

    private static string LuaCode(string token) => string.Join("\n",
    [
        "local token = \"" + token + "\"",
        "local epoch = \"unknown\"",
        "if Inspect and Inspect.Time and type(Inspect.Time.Server) == \"function\" then",
        "  local good, seconds = pcall(Inspect.Time.Server)",
        "  if good and type(seconds) == \"number\" then",
        "    epoch = string.format(\"%.3f\", seconds)",
        "  end",
        "end",
        "local msg = \"LPB_PROBE|\" .. token .. \"|\" .. epoch",
        "local ok, err = pcall(Command.Console.Display, \"general\", false, msg, false)",
        "print(ok and (\"Sent probe: \" .. token) or (\"Probe error: \" .. tostring(err)))"
    ]);

    public static async Task<int> Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--help")
        {
            Usage();
            return 0;
        }

        string? nonce = null;
        string? filePath = null;
        var timeoutMs = DefaultTimeoutMs;
        var pollMs = DefaultPollMs;
        var printLua = false;

        try
        {
            for (var i = 0; i < args.Length; i++)
            {
                var option = args[i];
                if (option == "--print-lua")
                {
                    printLua = true;
                    continue;
                }
                if (option is not ("--nonce" or "--path" or "--timeout-ms" or "--poll-ms")
                    || i + 1 >= args.Length)
                    throw new ArgumentException("Unknown or incomplete option.");
                var value = args[++i];
                switch (option)
                {
                    case "--nonce":
                        if (nonce is not null) throw new ArgumentException("Duplicate nonce.");
                        nonce = value;
                        break;
                    case "--path":
                        if (filePath is not null) throw new ArgumentException("Duplicate path.");
                        filePath = value;
                        break;
                    case "--timeout-ms":
                        if (!int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out timeoutMs))
                            throw new ArgumentException("Invalid timeout.");
                        break;
                    case "--poll-ms":
                        if (!int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out pollMs))
                            throw new ArgumentException("Invalid poll interval.");
                        break;
                }
            }
            if (nonce is null) throw new ArgumentException("Missing --nonce.");
            if (timeoutMs is < 1000 or > 300_000 || pollMs is < 25 or > 1000)
                throw new ArgumentException("Timeout or poll interval out of range.");

            filePath ??= DefaultLogPath();
            using var tail = new NoncombatLogTailer(filePath, nonce);
            if (printLua)
            {
                Console.WriteLine(LuaCode(nonce));
                return 0;
            }

            using var cancellation = new CancellationTokenSource();
            Console.CancelKeyPress += (_, e) =>
            {
                e.Cancel = true;
                cancellation.Cancel();
            };
            var elapsed = Stopwatch.StartNew();
            // Establish the existing-file EOF (or missing-file state) before announcing
            // readiness. Otherwise a marker arriving after "started" can be skipped.
            NoncombatLogPoll? firstObservation = tail.Poll();
            Write(new { @event = "started", path = filePath, nonce, pollMs, timeoutMs,
                activeGameInput = false });
            string? previous = null;
            while (elapsed.ElapsedMilliseconds < timeoutMs)
            {
                var observation = firstObservation ?? tail.Poll();
                firstObservation = null;
                if (observation.Status == "MATCHED")
                {
                    var receipt = observation.Match!;
                    Write(new
                    {
                        @event = "matched",
                        nonce = receipt.Nonce,
                        observedAtUtc = receipt.ObservedAtUtc,
                        serverEpochSeconds = receipt.ServerEpochSeconds,
                        serverClockDeltaMs = receipt.ServerClockDeltaMs,
                        isTrueFlushLatency = receipt.IsFlushLatencyMeasurement,
                        totalBytesRead = receipt.TotalBytesRead
                    });
                    return 0;
                }
                if (observation.Status != previous)
                {
                    Write(new { @event = observation.Status.ToLowerInvariant(),
                        code = observation.Reason });
                    previous = observation.Status;
                }
                try { await Task.Delay(pollMs, cancellation.Token); }
                catch (TaskCanceledException) { return 130; }
            }
            Write(new { @event = "timeout", nonce, elapsedMs = elapsed.ElapsedMilliseconds,
                matched = false });
            return 2;
        }
        catch (ArgumentException error)
        {
            Console.Error.WriteLine("Invalid options: " + error.Message);
            Usage();
            return 1;
        }
    }
}
