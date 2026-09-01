import Foundation

/// The honest live numbers, computed on-device as samples arrive.
///
/// **Why this exists.** `TrackRecorder` deliberately does no analysis, and the two numbers it does
/// show — `lastSpeed` and `roughDescent` — are throwaway liveness indicators computed the naive
/// way. On 2026-09-01 that stopped being acceptable: `roughDescent` sums every negative barometric
/// delta, which is exactly the method that puts Carve **+10.4%** over the truth, and the raw
/// `lastSpeed` is exactly the ungated field that let a four-second multipath burst become Carve's
/// published top speed for the day. Shipping an app whose entire thesis is measurement discipline
/// while its own screen shows the category's two bugs is not defensible.
///
/// **What it is.** A direct port of the two rules `Tools/analyze.py` earned in S5 — the hAcc speed
/// gate and run segmentation with the descent-merge fix — restated as a streaming computation, so
/// the number on the phone in a lift queue is the number the analyzer will print that evening.
///
/// **What it is not.** Not a replacement for offline analysis, and not on the recording path: it
/// only ever *reads* samples that have already been written. Analysis is rewritten and replayed
/// against saved files; a bug in here can cost a displayed number, never a recording.
///
/// Pure Foundation on purpose — no CoreLocation, no UIKit — so `Tools/replay.swift` can run the
/// exact same source over a fixture and check it against `analyze.py` without a device.
struct LiveMetrics {

    // MARK: - Constants (must match Tools/analyze.py)

    /// Barometric noise floor for committing a direction change.
    static let baroHysteresisM = 3.0
    /// A descent smaller than this is not a run.
    static let minRunDropM = 30.0
    /// Two descents separated by less re-ascent than this — and less time than `mergeGapS` — are
    /// one run interrupted by a sensor blip, not two runs. See S5: a 4.1 m pressure spike at a
    /// base building split a run and cost the day 16 m of real vertical.
    static let mergeAscentM = 15.0
    static let mergeGapS = 60.0
    /// **The gate that matters.** Horizontal accuracy is the field that actually degrades during
    /// multipath; on 2026-09-01 the day's median `speedAccuracy` was 2.04 m/s, so the old
    /// `speedAcc <= 2.0` gate threw away 57% of a healthy 1 Hz track *and still passed the glitch*.
    static let maxSpeedHAccM = 15.0
    /// Kept only as a loose sanity bound. Not load-bearing.
    static let maxSpeedAccMS = 3.0

    // MARK: - Output

    struct Run {
        /// When the skiing starts — the turning point plus however long the skier stood there.
        let startTime: TimeInterval
        /// The altitude turning point itself. `startTime - topTime` is time spent at the top.
        let topTime: TimeInterval
        let endTime: TimeInterval
        let drop: Double
        /// Time actually descending. See `descent_start` in `analyze.py` for why this excludes the
        /// wait at the top but keeps the runout at the bottom.
        var duration: TimeInterval { endTime - startTime }
    }

    /// Doppler maximum, accuracy-gated. **This is the number to show.** m/s; negative = none yet.
    private(set) var maxSpeed: Double = -1
    /// Ungated maximum, kept only so the gap between them is inspectable on the mountain — if these
    /// two ever diverge wildly the day contains a multipath burst worth looking at that evening.
    private(set) var maxSpeedUngated: Double = -1
    /// Completed runs of at least `minRunDropM`.
    private(set) var runs: [Run] = []
    /// Vertical the min-drop threshold discarded. Reported, never silently dropped — a day that
    /// loses much here is a day the thresholds are wrong for that mountain.
    private(set) var subThresholdDropM: Double = 0

    /// Vertical from completed runs only, measured top-to-bottom.
    var descentM: Double { runs.reduce(0) { $0 + $1.drop } }
    /// `descentM` plus the descent currently in progress, so the screen moves while skiing.
    var provisionalDescentM: Double { descentM + pendingDrop + liveDrop }
    var runCount: Int { runs.count }

    // MARK: - Segmenter state

    /// The descent that is closed but may still be extended by the merge rule.
    private var pendingTopAlt: Double?
    private var pendingTopTime: TimeInterval = 0
    private var pendingSkiFrom: TimeInterval = 0
    private var pendingBotAlt: Double = 0
    private var pendingBotTime: TimeInterval = 0
    private var pendingDrop: Double { pendingTopAlt.map { max(0, $0 - pendingBotAlt) } ?? 0 }

    /// Turning-point tracker over the altitude series.
    private var anchorAlt: Double?
    private var anchorTime: TimeInterval = 0
    private var direction = 0          // -1 descending, +1 ascending, 0 undecided
    private var legTopAlt: Double?     // altitude the current descending leg started from
    private var legTopTime: TimeInterval = 0
    private var legSkiStartTime: TimeInterval = 0

    /// Tracks the plateau at the top of a climb, so a run can start when the skier does.
    ///
    /// The batch version in `analyze.py` walks forward from the turning point through every sample
    /// still within `baroHysteresisM` of the ceiling and stops at the first departure. Streaming
    /// cannot walk forward — by the time a descent is *declared*, the samples spent standing at the
    /// top have already gone past, consumed by the ascending branch below. So the plateau is tracked
    /// as it happens and read off when the descent begins. The first departure is exactly the sample
    /// that triggers the transition, which is what makes the two implementations the same rule and
    /// not merely similar ones (R12a); `Tools/replay.sh` is what proves it.
    private var plateauCeiling: Double?
    private var plateauEnd: TimeInterval = 0
    /// Drop accumulated by the descending leg still in progress.
    private var liveDrop: Double {
        guard direction == -1, let legTopAlt, let anchorAlt else { return 0 }
        return max(0, legTopAlt - anchorAlt)
    }

    // MARK: - Ingest

    /// One GPS fix. Pass CoreLocation's values straight through; invalid ones are negative and are
    /// rejected here rather than at capture time.
    ///
    /// `dt` is seconds since the session started, and a **negative `dt` is rejected**: CoreLocation
    /// delivers its last cached fix the instant updates begin, so the first sample of every session
    /// predates it. `analyze.py` has always excluded these (it reports one on both Portillo files,
    /// the oldest 5.9 s early) and the port must too — a cached fix from the drive up the mountain
    /// carries the *car's* Doppler speed, and would otherwise be published as the day's top speed
    /// before the first run. It is still written to the file; this only keeps it out of the metric.
    mutating func ingestFix(speed: Double, horizontalAccuracy: Double, speedAccuracy: Double,
                            at dt: TimeInterval) {
        guard dt >= 0, speed >= 0 else { return }
        maxSpeedUngated = max(maxSpeedUngated, speed)
        guard horizontalAccuracy >= 0, horizontalAccuracy <= Self.maxSpeedHAccM,
              speedAccuracy >= 0, speedAccuracy <= Self.maxSpeedAccMS else { return }
        maxSpeed = max(maxSpeed, speed)
    }

    /// One barometric altitude reading. `altitude` may be relative — only differences are used.
    mutating func ingestAltitude(_ altitude: Double, at time: TimeInterval) {
        guard let anchor = anchorAlt else {
            anchorAlt = altitude
            anchorTime = time
            resetPlateau(altitude, time)
            return
        }

        // Advance the top-of-climb plateau before the branches, but only while not already
        // descending: once the skier is going down, the plateau is settled and must stay frozen.
        if direction != -1 { trackPlateau(altitude, time) }

        switch direction {
        case 0:
            if abs(altitude - anchor) >= Self.baroHysteresisM {
                direction = altitude < anchor ? -1 : 1
                if direction == -1 {
                    legTopAlt = anchor
                    legTopTime = anchorTime
                    legSkiStartTime = plateauEnd
                }
                anchorAlt = altitude
                anchorTime = time
                resetPlateau(altitude, time)
            }
        case -1:
            if altitude < anchor {
                anchorAlt = altitude
                anchorTime = time
            } else if altitude - anchor >= Self.baroHysteresisM {
                // The descent bottomed out at the anchor; it is now a closed descent.
                closeDescent(topAlt: legTopAlt ?? anchor, topTime: legTopTime,
                             skiFrom: legSkiStartTime, botAlt: anchor, botTime: anchorTime)
                legTopAlt = nil
                direction = 1
                anchorAlt = altitude
                anchorTime = time
                resetPlateau(altitude, time)
            }
        default:
            if altitude > anchor {
                anchorAlt = altitude
                anchorTime = time
            } else if anchor - altitude >= Self.baroHysteresisM {
                // Peak of the ascent — a new descent starts here. `plateauEnd` is the last moment
                // the skier was still up at that peak; this sample is the first departure from it.
                legTopAlt = anchor
                legTopTime = anchorTime
                legSkiStartTime = plateauEnd
                direction = -1
                anchorAlt = altitude
                anchorTime = time
                resetPlateau(altitude, time)
            }
        }
    }

    private mutating func resetPlateau(_ altitude: Double, _ time: TimeInterval) {
        plateauCeiling = altitude
        plateauEnd = time
    }

    private mutating func trackPlateau(_ altitude: Double, _ time: TimeInterval) {
        guard let ceiling = plateauCeiling else { return resetPlateau(altitude, time) }
        if altitude >= ceiling {
            plateauCeiling = altitude
            plateauEnd = time
        } else if altitude >= ceiling - Self.baroHysteresisM {
            plateauEnd = time
        }
        // Below the band: the skier has left the top. Freeze `plateauEnd` where it is.
    }

    /// Call when the altitude baseline is about to jump — `CMAltimeter.relativeAltitude` restarts
    /// from zero every time updates begin, so a resumed session's first reading is discontinuous.
    /// Summing across that seam is how a 400 m descent got reported as 800 m in S4. Everything
    /// already segmented is kept; only the in-flight leg is abandoned, because a descent that
    /// straddles a seam has an unknown size and an unknown is not guessed.
    mutating func beginAltitudeSegment() {
        finalizePending()
        anchorAlt = nil
        direction = 0
        legTopAlt = nil
        plateauCeiling = nil   // the altitudes either side of a seam are not comparable
    }

    /// Close out the session. The descent in progress ends wherever the last sample left it.
    mutating func finish() {
        if direction == -1, let top = legTopAlt, let anchor = anchorAlt {
            closeDescent(topAlt: top, topTime: legTopTime, skiFrom: legSkiStartTime,
                         botAlt: anchor, botTime: anchorTime)
            legTopAlt = nil
        }
        finalizePending()
    }

    // MARK: - Segmenting

    private mutating func closeDescent(topAlt: Double, topTime: TimeInterval,
                                       skiFrom: TimeInterval,
                                       botAlt: Double, botTime: TimeInterval) {
        guard topAlt - botAlt > 0 else { return }

        // The merge rule, applied *before* the min-drop filter — the order is the whole point.
        // A merged run keeps the *first* descent's top and ski start: the blip that split it was
        // never a stop at the top, so the second half contributes only its bottom.
        if let prevTop = pendingTopAlt,
           topAlt - pendingBotAlt < Self.mergeAscentM,
           topTime - pendingBotTime < Self.mergeGapS {
            _ = prevTop
            pendingBotAlt = botAlt
            pendingBotTime = botTime
            return
        }

        finalizePending()
        pendingTopAlt = topAlt
        pendingTopTime = topTime
        pendingSkiFrom = skiFrom
        pendingBotAlt = botAlt
        pendingBotTime = botTime
    }

    private mutating func finalizePending() {
        guard let top = pendingTopAlt else { return }
        let drop = top - pendingBotAlt
        if drop >= Self.minRunDropM {
            runs.append(Run(startTime: pendingSkiFrom, topTime: pendingTopTime,
                            endTime: pendingBotTime, drop: drop))
        } else if drop > 0 {
            subThresholdDropM += drop
        }
        pendingTopAlt = nil
    }
}
