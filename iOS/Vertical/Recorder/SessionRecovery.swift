import Foundation

/// Finds a recording that was interrupted rather than stopped, so the app can pick it up again
/// without asking.
///
/// The failure this exists for is not hypothetical and not rare: iOS jetsams background apps under
/// memory pressure, and a lithium battery at -10 °C can read 20 % and then cut out. Either way the
/// phone comes back and — before this file existed — the app came back **IDLE** while Martin
/// carried on skiing, and the rest of the day was gone. That is precisely the 1★ failure mode in
/// `RESEARCH.md` §5.2 that the whole project is a reaction to.
///
/// The rule everywhere here is **never ask a question**. No "resume or finish?" prompt: those are
/// what triple other apps' run totals when tapped wrong on a chairlift. We decide, we say what we
/// did in a banner, and STOP is always one press away if we decided wrong.
nonisolated enum SessionRecovery {

    /// What a scan of one unterminated session file turned up.
    struct Interrupted {
        let url: URL
        /// Wall clock the *original* session started — resumed samples keep counting `dt` from
        /// here, so the file stays one continuous timeline.
        let startedAt: Date
        let sessionID: String
        let locCount: Int
        let baroCount: Int
        let markCount: Int
        /// Wall clock of the last sample we can see, i.e. the moment recording actually died.
        let lastSampleAt: Date
        /// How long the phone was out of action.
        var gap: TimeInterval { Date().timeIntervalSince(lastSampleAt) }
    }

    /// How long a gap we're still willing to treat as "the same ski day, interrupted".
    ///
    /// Deliberately generous. The two mistakes are not symmetric: resuming a session that should
    /// have ended costs a visible banner and one press of STOP, while failing to resume one costs
    /// an afternoon of skiing that cannot be re-skied. A dead battery warmed up over lunch is
    /// easily an hour, so six hours it is.
    static let maxResumeGap: TimeInterval = 6 * 3600

    /// The newest session file that has no `end` record and died recently enough to be worth
    /// continuing. `nil` when the last session was closed cleanly, is too old, or is unreadable.
    static func findInterrupted(in directory: URL, now: Date = Date()) -> Interrupted? {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []

        // Only the newest file can be the one still in progress. If that one closed cleanly, an
        // older unterminated file is an ancient crash, not today's — leave it alone.
        guard let newest = files.first, let scan = scan(newest) else { return nil }
        guard !scan.closedCleanly else { return nil }
        guard now.timeIntervalSince(scan.lastSampleAt) <= maxResumeGap else { return nil }

        return Interrupted(url: newest,
                           startedAt: scan.startedAt,
                           sessionID: scan.sessionID,
                           locCount: scan.locCount,
                           baroCount: scan.baroCount,
                           markCount: scan.markCount,
                           lastSampleAt: scan.lastSampleAt)
    }

    // MARK: - Scanning

    private struct Scan {
        var startedAt: Date
        var sessionID: String
        var closedCleanly = false
        var locCount = 0
        var baroCount = 0
        var markCount = 0
        var maxDt: TimeInterval = 0
        var lastSampleAt: Date { startedAt.addingTimeInterval(maxDt) }
    }

    /// One pass over the file. Full JSON decoding happens only for the header; every other line is
    /// classified by a byte probe and read for `dt` alone.
    ///
    /// **This runs synchronously inside `App.init()`**, before there is a screen — and on a
    /// background relaunch after a jetsam kill there may never *be* one, with seconds of wall
    /// clock to work with. So its cost is a correctness property, not a nicety, and it has to be
    /// measured rather than asserted.
    ///
    /// It was measured, in S18, and the first version was not cheap at all: **4.3 s on a Mac** —
    /// `-O`, warm page cache — for the 56 MB day-4 file, and a phone is slower than that. The
    /// cause was not the file size but a per-line cost paid five times over: each line was
    /// converted to a `String` by `value(of:)`, and `contains` called it once per candidate tag,
    /// so the *largest* lines (a 1.6 kB IMU batch matches none of the four tags) paid the most.
    /// Scanning the bytes instead, and classifying once, is the same rule at ~1/40th the cost.
    /// The two are pinned together by `recoveryScanMatchesAFullReplay`, which cross-checks the
    /// counts against `SessionReplay`'s independent parse of a real day.
    private static func scan(_ url: URL) -> Scan? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }

        var header: Scan?

        // Explicitly the raw-buffer overload: `Data.withUnsafeBytes` also has a deprecated
        // `UnsafePointer<T>` form, and an unannotated closure leaves the two ambiguous.
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var i = bytes.startIndex

            while i < bytes.endIndex {
                var j = i
                while j < bytes.endIndex, bytes[j] != 0x0A { j += 1 }
                let line = bytes[i..<j]
                i = j + 1
                if line.isEmpty { continue }

                guard var scan = header else {
                    // The header is the first line and the only one worth decoding properly:
                    // without it we have no timeline to resume onto. Lines before it (there
                    // shouldn't be any) are skipped rather than treated as fatal.
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601
                    if let meta = try? dec.decode(MetaSample.self, from: Data(line)) {
                        header = Scan(startedAt: meta.startedAt, sessionID: meta.sessionID)
                    }
                    continue
                }

                // Classified once per line. The old form asked the same question up to four times.
                if let kind = valueRange(of: Self.tKey, in: line) {
                    if matches(kind, in: line, SampleKind.end.rawValue) {
                        scan.closedCleanly = true
                    } else if matches(kind, in: line, SampleKind.loc.rawValue) {
                        scan.locCount += 1
                    } else if matches(kind, in: line, SampleKind.baro.rawValue) {
                        scan.baroCount += 1
                    } else if matches(kind, in: line, SampleKind.mark.rawValue) {
                        scan.markCount += 1
                    }
                }

                // A line with no readable `dt` is the torn tail a power cut leaves behind. Not
                // fatal: it just doesn't move the clock, and the writer closes it off before
                // appending.
                if let r = valueRange(of: Self.dtKey, in: line), let dt = double(r, in: line) {
                    scan.maxDt = max(scan.maxDt, dt)
                }

                header = scan
            }
        }

        return header
    }

    // MARK: - Byte probes

    /// One line of the mapped file. Indices are absolute into the whole buffer.
    private typealias Line = Slice<UnsafeBufferPointer<UInt8>>

    private static let tKey = Array("\"t\"".utf8)
    private static let dtKey = Array("\"dt\"".utf8)

    /// The byte range of one top-level scalar's value, tolerating whitespace around the colon and
    /// returning string values unquoted.
    ///
    /// Deliberately more forgiving than the files we write. `JSONEncoder` never emits a space
    /// after a colon, so a literal `"t":"end"` search matches everything the app produces — and
    /// then fails silently on a file that came from anywhere else, which is precisely how a
    /// recovery check ends up quietly deciding that a finished session is still running. Being
    /// strict buys nothing here; being wrong costs a resume that shouldn't happen.
    private static func valueRange(of key: [UInt8], in line: Line) -> Range<Int>? {
        guard var p = firstIndex(of: key, in: line) else { return nil }
        while p < line.endIndex, line[p] == 0x20 { p += 1 }            // space
        guard p < line.endIndex, line[p] == 0x3A else { return nil }   // ':'
        p += 1
        while p < line.endIndex, line[p] == 0x20 { p += 1 }
        guard p < line.endIndex else { return nil }

        if line[p] == 0x22 {                                           // '"'
            p += 1
            var q = p
            while q < line.endIndex, line[q] != 0x22 { q += 1 }
            return p..<q
        }
        var q = p
        while q < line.endIndex, isScalarByte(line[q]) { q += 1 }
        return q > p ? p..<q : nil
    }

    /// Index just past `key`, or nil. `key` is short and the hit is usually early, so a plain
    /// scan beats anything cleverer here.
    private static func firstIndex(of key: [UInt8], in line: Line) -> Int? {
        guard line.count >= key.count else { return nil }
        let last = line.endIndex - key.count
        var i = line.startIndex
        while i <= last {
            if line[i] == key[0] {
                var k = 1
                while k < key.count, line[i + k] == key[k] { k += 1 }
                if k == key.count { return i + key.count }
            }
            i += 1
        }
        return nil
    }

    private static func isScalarByte(_ b: UInt8) -> Bool {
        (b >= 0x30 && b <= 0x39)        // 0-9
            || b == 0x2E || b == 0x2D   // . -
            || b == 0x65 || b == 0x45   // e E
            || b == 0x2B                // +
    }

    private static func matches(_ r: Range<Int>, in line: Line, _ s: String) -> Bool {
        let want = Array(s.utf8)
        guard r.count == want.count else { return false }
        for (k, idx) in r.enumerated() where line[idx] != want[k] { return false }
        return true
    }

    /// Parses the few bytes of a number. Only the value is converted, never the whole line —
    /// which is the entire point of the rewrite above.
    private static func double(_ r: Range<Int>, in line: Line) -> Double? {
        var text = ""
        text.reserveCapacity(r.count)
        for idx in r { text.append(Character(UnicodeScalar(line[idx]))) }
        return Double(text)
    }
}
