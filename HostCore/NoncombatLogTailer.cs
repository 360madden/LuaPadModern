using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaPadModern.HostCore;

// A tagged, read-only noncombat log observation. Clock delta is NOT log-flush latency.
public sealed record NoncombatLogMatch(
    string Nonce,
    DateTimeOffset ObservedAtUtc,
    double? ServerEpochSeconds,
    long? ServerClockDeltaMs,
    long TotalBytesRead,
    bool IsFlushLatencyMeasurement = false);

public sealed record NoncombatLogPoll(
    string Status,
    NoncombatLogMatch? Match = null,
    string? Reason = null);

// Single-reader source component; no game input, file writes, process/window APIs or MCP calls.
// A host service may call Poll periodically and publish only matching probe metadata.
public sealed class NoncombatLogTailer : IDisposable
{
    public const int MaximumBytesPerPoll = 256 * 1024;
    public const int MaximumLineChars = 8192;
    private const string Prefix = "LPB_PROBE|";
    private static readonly Regex TokenPattern = new(
        @"\A[A-Za-z0-9_-]{8,80}\z", RegexOptions.CultureInvariant);
    private static readonly Regex EpochPrefix = new(
        @"\A[0-9]+(?:\.[0-9]+)?", RegexOptions.CultureInvariant);

    private readonly string _path;
    private readonly string _nonce;
    private readonly string _marker;
    private readonly bool _fromStart;
    private readonly int _readBudget;
    private readonly StringBuilder _line = new();
    private FileStream? _stream;
    private Decoder? _decoder;
    private Encoding? _encoding;
    private DateTime _creationTimeUtc;
    private long _offset;
    private long _totalBytesRead;
    private bool _firstObservation = true;
    private bool _readNewFileFromBeginning;
    private bool _disposed;
    private NoncombatLogMatch? _match;

    public NoncombatLogTailer(
        string filePath, string nonce, bool fromStart = false,
        int maximumBytesPerPoll = MaximumBytesPerPoll)
    {
        if (string.IsNullOrWhiteSpace(filePath) || !Path.IsPathFullyQualified(filePath))
            throw new ArgumentException("Log path must be absolute.", nameof(filePath));
        if (nonce is null || !TokenPattern.IsMatch(nonce))
            throw new ArgumentException("Nonce must be 8-80 ASCII token characters.", nameof(nonce));
        if (maximumBytesPerPoll is < 1 or > MaximumBytesPerPoll)
            throw new ArgumentOutOfRangeException(nameof(maximumBytesPerPoll));

        _path = Path.GetFullPath(filePath);
        _nonce = nonce;
        _marker = Prefix + nonce + "|";
        _fromStart = fromStart;
        _readBudget = maximumBytesPerPoll;
    }

    public NoncombatLogPoll Poll(DateTimeOffset? observedAtUtc = null)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (_match is not null) return new NoncombatLogPoll("MATCHED", _match);

        var observedAt = (observedAtUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        try
        {
            var info = new FileInfo(_path);
            if (!info.Exists)
            {
                CloseCurrentFile();
                _firstObservation = false;
                _readNewFileFromBeginning = true;
                return new NoncombatLogPoll("WAITING_FOR_FILE");
            }

            // Retain no stale partial line when a file is truncated or replaced.
            // Creation time is a best-effort managed identity, not an NTFS file ID.
            if (_stream is not null &&
                (info.Length < _offset || info.CreationTimeUtc != _creationTimeUtc))
            {
                CloseCurrentFile();
                _readNewFileFromBeginning = true;
            }

            if (_stream is null)
            {
                _stream = new FileStream(_path, FileMode.Open, FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete, 4096, FileOptions.SequentialScan);
                _creationTimeUtc = info.CreationTimeUtc;
                _offset = _firstObservation && !_fromStart && !_readNewFileFromBeginning
                    ? _stream.Length : 0;
                _stream.Position = _offset;
                _firstObservation = false;
                _readNewFileFromBeginning = false;
            }

            if (_decoder is null)
            {
                // Wait for the second byte rather than misdetect a split UTF-16 BOM.
                if (_stream.Length < 2) return new NoncombatLogPoll("WATCHING");
                _stream.Position = 0;
                var first = _stream.ReadByte();
                var second = _stream.ReadByte();
                _encoding = (first == 0xff && second == 0xfe) ||
                            (first != 0 && second == 0)
                    ? new UnicodeEncoding(false, true, false)
                    : new UTF8Encoding(false, false);
                _decoder = _encoding.GetDecoder();
                _stream.Position = _offset;
            }

            var remaining = Math.Min(_stream.Length - _offset, _readBudget);
            while (remaining > 0)
            {
                var bytes = new byte[(int)Math.Min(4096, remaining)];
                var count = _stream.Read(bytes, 0, bytes.Length);
                if (count == 0) break;
                _offset += count;
                _totalBytesRead += count;
                remaining -= count;

                var characters = new char[_encoding!.GetMaxCharCount(count)];
                var decoded = _decoder.GetChars(bytes, 0, count, characters, 0, false);
                for (var i = 0; i < decoded; i++)
                {
                    if (characters[i] == '\n')
                    {
                        InspectLine(observedAt);
                        _line.Clear();
                        if (_match is not null)
                            return new NoncombatLogPoll("MATCHED", _match);
                    }
                    else
                    {
                        _line.Append(characters[i]);
                        // Bound RAM even if a game log writer emits a line without newline.
                        if (_line.Length > MaximumLineChars)
                            _line.Remove(0, Math.Min(1024, _line.Length));
                    }
                }
            }
            return new NoncombatLogPoll("WATCHING");
        }
        catch (UnauthorizedAccessException)
        {
            CloseCurrentFile();
            _readNewFileFromBeginning = true;
            return new NoncombatLogPoll("READ_ERROR", Reason: "ACCESS_DENIED");
        }
        catch (IOException)
        {
            CloseCurrentFile();
            _readNewFileFromBeginning = true;
            return new NoncombatLogPoll("READ_ERROR", Reason: "IO_FAILURE");
        }
    }

    private void InspectLine(DateTimeOffset observedAtUtc)
    {
        var text = _line.ToString().TrimEnd('\r');
        var index = text.IndexOf(_marker, StringComparison.Ordinal);
        if (index < 0) return;

        var rest = text[(index + _marker.Length)..];
        var epochMatch = EpochPrefix.Match(rest);
        double? seconds = null;
        long? clockDelta = null;
        if (epochMatch.Success &&
            double.TryParse(epochMatch.Value, NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture, out var parsed) &&
            parsed is >= 1_500_000_000 and < 4_200_000_000)
        {
            seconds = parsed;
            clockDelta = (long)Math.Round(
                observedAtUtc.ToUnixTimeMilliseconds() - parsed * 1000d);
        }
        _match = new NoncombatLogMatch(
            _nonce, observedAtUtc, seconds, clockDelta, _totalBytesRead);
    }

    private void CloseCurrentFile()
    {
        _stream?.Dispose();
        _stream = null;
        _decoder = null;
        _encoding = null;
        _offset = 0;
        _line.Clear();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        CloseCurrentFile();
        GC.SuppressFinalize(this);
    }
}
