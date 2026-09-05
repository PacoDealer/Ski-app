import Foundation

/// Reads a saved session file back and produces the numbers for it.
///
/// **Why this exists.** Until now the app computed runs, vertical and top speed live in
/// `LiveMetrics` and then **threw them away at STOP** — after a ski day `SessionsView` could show
/// filenames and byte counts, and every interesting number needed a Mac, a cable and Python. That
/// is also precisely the line Slopes draws its paywall on: their free tier gives a daily summary,
/// and per-run detail is Premium (S8 audit, `RESEARCH.md` §13.5). We already compute it; we were
/// just discarding it.
///
/// **One rule, one implementation (R12a).** This does not re-derive anything. It replays the file
/// through the same `LiveMetrics` the recorder uses live, so the phone, `Tools/replay.sh` and
/// `Tools/analyze.py` cannot drift apart without the replay harness saying so. The parsing loop
/// lives here rather than in the harness for the same reason — `Tools/replay.swift` compiles this
/// file too, so "what counts as a resume seam" is decided once.
///
/// **Pure Foundation on purpose** — no CoreLocation, no SwiftUI — so it compiles on the Mac for
/// the harness, and so it can safely run off the main thread on a 20 MB file.
nonisolated enum SessionReplay {

    /// Everything a detail screen needs, and nothing that needs a device to compute.
    struct Summary {
        var metrics = LiveMetrics()

        // Header, from the `meta` record.
        var startedAt: Date?
        var device = ""
        var osVersion = ""
        var appVersion = ""
        var formatVersion = 0

        /// Session length, taken from the last `dt` seen — which is the `end` record's on a clean
        /// file, and the last sample written on an interrupted one.
        var duration: TimeInterval = 0
        var closedCleanly = false
        var byteCount = 0

        var locCount = 0
        /// Fixes CoreLocation delivered from its cache *before* the session started (negative
        /// `dt`). Excluded from every metric — one of these carries the car's Doppler speed and
        /// would otherwise be the day's top speed. `analyze.py` reports them the same way.
        var staleFixCount = 0
        var baroCount = 0
        var markCount = 0
        /// Individual motion samples, not batches.
        var imuCount = 0
        /// `CMAltimeter` baseline restarts, i.e. how many times the session was interrupted.
        var resumeSeams = 0

        /// Fixes carrying a usable Doppler speed. The field max speed depends on.
        var dopplerValidCount = 0
        /// Median horizontal accuracy in metres; negative if there were no valid fixes.
        var hAccMedian: Double = -1
        /// Fixes the speed gate rejected — the cost of the accuracy gate, stated rather than hidden.
        var speedGateRejected = 0

        /// Effective motion rate over the stretch that actually carried motion, in Hz.
        var imuRateHz: Double = 0
        /// The longest silence between motion batches. **The number that matters**: a file with
        /// 40 min of motion inside a 3 h day looks fine by every other measure. Negative = no IMU.
        var imuMaxGapS: Double = -1
        /// Fraction of the session covered by motion batches, 0…1.
        var imuCoverage: Double = 0

        /// Hand tags, in order, as `(dt, label)`.
        var marks: [(dt: TimeInterval, label: String)] = []

        /// The line on the ground, for a map. Empty unless `summarize` was asked for it — the
        /// recorder and the replay harness never need it and never pay for it. See `SessionTrack`.
        var track = SessionTrack()

        var runs: [LiveMetrics.Run] { metrics.runs }
        var descentM: Double { metrics.descentM }
        var maxSpeedMS: Double { metrics.maxSpeed }
        var maxSpeedUngatedMS: Double { metrics.maxSpeedUngated }

        /// Time spent descending, summed over completed runs. Compare against `duration` for the
        /// share of the day actually skiing — Slopes prints the same pair on its day card.
        var skiTime: TimeInterval { metrics.runs.reduce(0) { $0 + $1.duration } }
        /// Ground distance covered while descending, summed over runs. Excludes lifts, which is
        /// how Slopes reports it too — its activity `distance` is exactly the sum of its runs'.
        var descentDistanceM: Double { metrics.runs.reduce(0) { $0 + $1.distanceM } }
        var dopplerRatio: Double {
            locCount > 0 ? Double(dopplerValidCount) / Double(locCount) : 0
        }
    }

    enum Failure: Error { case unreadable }

    /// Replay one session file. Blocking and CPU-bound — call it off the main thread.
    ///
    /// - Parameter collectTrack: also keep every drawable fix, for a map. Off by default so the
    ///   one caller that wants a line on the ground pays for it and nothing else does.
    static func summarize(_ url: URL, collectTrack: Bool = false) throws -> Summary {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw Failure.unreadable
        }

        var s = Summary()
        s.byteCount = data.count

        var hAccs: [Double] = []
        var imuFirstDt: TimeInterval?
        var imuLastEnd: TimeInterval?
        var imuMaxGap: Double = 0
        var imuCoveredS: Double = 0

        for line in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let kind = obj["t"] as? String else { continue }
            let dt = obj["dt"] as? Double ?? 0
            s.duration = max(s.duration, dt)

            switch kind {
            case "meta":
                s.device = obj["device"] as? String ?? ""
                s.osVersion = obj["osVersion"] as? String ?? ""
                s.appVersion = obj["appVersion"] as? String ?? ""
                s.formatVersion = obj["formatVersion"] as? Int ?? 0
                if let iso = obj["startedAt"] as? String {
                    s.startedAt = Self.parseDate(iso)
                } else if let epoch = obj["startedAt"] as? Double {
                    // JSONEncoder's default date strategy is seconds since the 2001 reference date.
                    s.startedAt = Date(timeIntervalSinceReferenceDate: epoch)
                }

            case "loc":
                guard dt >= 0 else { s.staleFixCount += 1; break }
                s.locCount += 1
                let speed = obj["speed"] as? Double ?? -1
                let hAcc = obj["hAcc"] as? Double ?? -1
                let speedAcc = obj["speedAcc"] as? Double ?? -1
                if speed >= 0, speedAcc >= 0 { s.dopplerValidCount += 1 }
                if hAcc >= 0 { hAccs.append(hAcc) }
                // A fix that carried a Doppler speed the gate then refused. Restating the gate
                // here rather than inferring it from `maxSpeed` is deliberate: a fix can pass the
                // gate and still not move the maximum, so the two are not the same question.
                if speed >= 0,
                   !(hAcc >= 0 && hAcc <= LiveMetrics.maxSpeedHAccM
                     && speedAcc >= 0 && speedAcc <= LiveMetrics.maxSpeedAccMS) {
                    s.speedGateRejected += 1
                }
                let lat = obj["lat"] as? Double ?? .nan
                let lon = obj["lon"] as? Double ?? .nan
                s.metrics.ingestFix(speed: speed, horizontalAccuracy: hAcc,
                                    speedAccuracy: speedAcc,
                                    latitude: lat, longitude: lon,
                                    at: dt)
                if collectTrack {
                    s.track.append(dt: dt, lat: lat, lon: lon,
                                   altitude: obj["alt"] as? Double ?? .nan, speed: speed,
                                   horizontalAccuracy: hAcc, speedAccuracy: speedAcc)
                }

            case "baro":
                s.baroCount += 1
                s.metrics.ingestAltitude(obj["relAlt"] as? Double ?? 0, at: dt)

            case "imu":
                let n = (obj["ax"] as? [Double])?.count ?? 0
                guard n > 0 else { break }
                s.imuCount += n
                let hz = obj["hz"] as? Double ?? 25
                let span = Double(n) / max(hz, 1)
                if imuFirstDt == nil { imuFirstDt = dt }
                if let last = imuLastEnd { imuMaxGap = max(imuMaxGap, dt - last) }
                imuLastEnd = dt + span
                imuCoveredS += span

            case "mark":
                s.markCount += 1
                if let label = obj["label"] as? String { s.marks.append((dt, label)) }

            case "note":
                // Must match `Tools/replay.swift` and the recorder: the altimeter's baseline
                // restarts at zero on a resume, and summing across that seam is how a 400 m
                // descent got reported as 800 m in S4.
                if let text = obj["text"] as? String, text.hasPrefix("resumed after interruption") {
                    s.resumeSeams += 1
                    s.metrics.beginAltitudeSegment()
                }

            case "end":
                s.closedCleanly = true

            default:
                break
            }
        }
        s.metrics.finish()

        if !hAccs.isEmpty {
            hAccs.sort()
            s.hAccMedian = hAccs[hAccs.count / 2]
        }
        if let first = imuFirstDt, let last = imuLastEnd, s.imuCount > 0 {
            // Rate over the stretch that carried motion; coverage over the whole session. Keeping
            // them separate is the point — 25 Hz for 40 min of a 3 h day is a *good* rate and a
            // ruined recording, and only the coverage line says so.
            s.imuRateHz = Double(s.imuCount) / max(last - first, 0.001)
            s.imuMaxGapS = max(imuMaxGap, first)         // silence before the first batch counts
            if s.duration > 0 { s.imuCoverage = min(1, imuCoveredS / s.duration) }
        }
        return s
    }

    /// `SampleWriter` encodes dates as plain ISO-8601; the fractional-seconds variant is only a
    /// hedge against a future encoder change. Built per call rather than cached in a static —
    /// `ISO8601DateFormatter` is not `Sendable`, this runs off the main thread, and it happens
    /// exactly once per file.
    private static func parseDate(_ s: String) -> Date? {
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}
