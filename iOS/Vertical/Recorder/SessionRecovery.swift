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
    /// classified by a substring probe and read for `dt` alone.
    ///
    /// A full day is tens of thousands of lines and this runs on the launch path — possibly a
    /// background launch with seconds of wall clock to work with — so it stays deliberately cheap.
    private static func scan(_ url: URL) -> Scan? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }

        var header: Scan?

        for slice in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            let line = Data(slice)

            guard var scan = header else {
                // The header is the first line and the only one worth decoding properly: without
                // it we have no timeline to resume onto. Lines before it (there shouldn't be any)
                // are skipped rather than treated as fatal.
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                if let meta = try? dec.decode(MetaSample.self, from: line) {
                    header = Scan(startedAt: meta.startedAt, sessionID: meta.sessionID)
                }
                continue
            }

            if contains(line, tag: SampleKind.end.rawValue) {
                scan.closedCleanly = true
            } else if contains(line, tag: SampleKind.loc.rawValue) {
                scan.locCount += 1
            } else if contains(line, tag: SampleKind.baro.rawValue) {
                scan.baroCount += 1
            } else if contains(line, tag: SampleKind.mark.rawValue) {
                scan.markCount += 1
            }

            // A line with no readable `dt` is the torn tail a power cut leaves behind. Not fatal:
            // it just doesn't move the clock, and the writer closes it off before appending.
            if let dt = dt(in: line) { scan.maxDt = max(scan.maxDt, dt) }

            header = scan
        }

        return header
    }

    /// True when the line's `"t"` field is `tag`.
    private static func contains(_ line: Data, tag: String) -> Bool {
        value(of: "t", in: line) == tag
    }

    /// Pulls `dt` out without building a full object.
    private static func dt(in line: Data) -> TimeInterval? {
        value(of: "dt", in: line).flatMap(TimeInterval.init)
    }

    /// Reads one top-level scalar out of a JSON line as text, tolerating whitespace around the
    /// colon and returning string values unquoted.
    ///
    /// This is deliberately more forgiving than the files we write. `JSONEncoder` never emits a
    /// space after a colon, so a literal `"t":"end"` search matches everything the app produces —
    /// and then fails silently on a file that came from anywhere else, which is precisely how a
    /// recovery check ends up quietly deciding that a finished session is still running. Being
    /// strict buys nothing here; being wrong costs a resume that shouldn't happen.
    private static func value(of key: String, in line: Data) -> String? {
        guard let text = String(data: line, encoding: .utf8),
              let range = text.range(of: "\"\(key)\"") else { return nil }

        var rest = Substring(text[range.upperBound...]).drop { $0 == " " }
        guard rest.first == ":" else { return nil }
        rest = rest.dropFirst().drop { $0 == " " }

        if rest.first == "\"" {
            return String(rest.dropFirst().prefix { $0 != "\"" })
        }
        let scalar = rest.prefix { $0.isNumber || $0 == "." || $0 == "-" || $0 == "e" || $0 == "+" }
        return scalar.isEmpty ? nil : String(scalar)
    }
}
