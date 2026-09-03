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
///
/// `nonisolated` for the same reason (S9): the app target defaults to main-actor isolation, and
/// `SessionReplay` runs this over a whole file on a background task so opening a saved day does
/// not freeze the UI. Nothing in here touches shared state — it is a value type over numbers.
nonisolated struct LiveMetrics {

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
    /// A position fix worse than this is not used for distance or for a run's endpoints. Looser
    /// than the speed gate on purpose: `maxSpeedHAccM` exists because Doppler goes wrong in ways
    /// hAcc predicts, while a ±20 m fix still places you on the right pitch. Matches `MAX_H_ACC`.
    static let maxPositionHAccM = 25.0
    /// Shortest interval between two fixes used as a distance step.
    ///
    /// **This is the distance equivalent of the vertical bug.** Summing every 1 Hz step reads
    /// **+9.8%** against Slopes' itemised run distances across the three graded days — the same
    /// shape as the 5–10% vertical overestimate the whole project exists to criticise, in our own
    /// code. The cause is not exotic: at 1 Hz a skier moves ~10 m between fixes while the median
    /// fix is ±7 m, so scatter is a large fraction of every step, and scatter only ever adds.
    ///
    /// **Calibrated over Slopes' own run windows rather than ours**, which is the part that
    /// matters. Our runs end ~60 s later than Slopes' because `descent_start` deliberately keeps
    /// the runout, so fitting against our own windows tunes the estimator to absorb a
    /// *segmentation* difference and lands on 3.0 s. Removing segmentation from the question gives
    /// **2.5 s**, and takes the per-run error from **8.8% to 1.6%** (day totals ≈1.0%).
    ///
    /// The knob is quantised by the fix rate — at 1 Hz anything in (2, 3] keeps roughly every third
    /// fix — so 2.5 sits mid-plateau rather than on a boundary where jitter flips the step between
    /// 2 and 3 fixes. Three days (R5); re-score with `Tools/grade.py` on a fourth.
    static let minDistanceDtS = 2.5

    // MARK: - Output

    struct Run {
        /// When the skiing starts — the turning point plus however long the skier stood there.
        let startTime: TimeInterval
        /// The altitude turning point itself. `startTime - topTime` is time spent at the top.
        let topTime: TimeInterval
        let endTime: TimeInterval
        let drop: Double
        /// Ground distance covered between `startTime` and `endTime`, summed over position fixes
        /// inside `maxPositionHAccM`. Zero when the run carried no usable fix.
        var distanceM: Double = 0
        /// The gated Doppler maximum *within this run*, m/s; negative if the run had none. Not the
        /// day maximum — a run's own top speed is half of what a comparison between two runs is.
        var topSpeedMS: Double = -1
        /// First and last usable position of the run, for matching one run against another later.
        var startLat: Double = .nan
        var startLon: Double = .nan
        var endLat: Double = .nan
        var endLon: Double = .nan

        /// Time actually descending. See `descent_start` in `analyze.py` for why this excludes the
        /// wait at the top but keeps the runout at the bottom.
        var duration: TimeInterval { endTime - startTime }
        /// Mean speed over the ground while descending, m/s. Slopes prints this per run.
        var averageSpeedMS: Double { duration > 0 ? distanceM / duration : 0 }
        /// Vertical metres per second — separates a pitch from a traverse with no map.
        var verticalRateMS: Double { duration > 0 ? drop / duration : 0 }
        var hasPosition: Bool { !startLat.isNaN && !endLat.isNaN }
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
    /// `runCount` plus the closed-but-still-mergeable descent, so the RUNS tile counts the same
    /// descents `provisionalDescentM` is already adding up.
    ///
    /// A descent is held in `pending` until either the next one closes or the session ends, because
    /// the merge rule may still absorb it. `provisionalDescentM` includes that pending drop; before
    /// 2026-09-02 `runCount` did not, so the live screen showed one fewer run than its own vertical
    /// accounted for — permanently, from the last run of the day until STOP. On 2026-09-02 the phone
    /// read 7 runs / 1,386 m while a replay of the same bytes read 8 runs / 1,386 m (S12).
    ///
    /// Two descents can be outstanding at once — one closed into `pending`, one still descending —
    /// which is why standing at the bottom after the last run of the day showed the tile *two*
    /// behind its own vertical. Both are counted here, on the same min-drop threshold that decides
    /// whether a descent becomes a run, and the merge rule is applied first so a leg that will be
    /// absorbed into `pending` counts once rather than twice.
    var provisionalRunCount: Int {
        var count = runs.count
        var pendingProvisionalDrop = pendingDrop
        var liveIsASeparateRun = liveDrop > 0

        if liveDrop > 0, let pendingTopAlt, let anchorAlt, let legTopAlt,
           legTopAlt - pendingBotAlt < Self.mergeAscentM,
           legTopTime - pendingBotTime < Self.mergeGapS {
            // Same shape as `closeDescent`'s merge: one run, measured from the higher top.
            pendingProvisionalDrop = max(0, max(pendingTopAlt, legTopAlt) - anchorAlt)
            liveIsASeparateRun = false
        }

        if pendingProvisionalDrop >= Self.minRunDropM { count += 1 }
        if liveIsASeparateRun, liveDrop >= Self.minRunDropM { count += 1 }
        return count
    }

    // MARK: - Position trail

    private struct Fix {
        let dt: TimeInterval
        let lat: Double
        let lon: Double
        /// Doppler speed if it passed the speed gate, else negative.
        let speed: Double
    }

    /// Recent position fixes, kept only long enough to measure the run they belong to.
    ///
    /// **Why a buffer and not the whole track.** A run's window is not known until the run closes —
    /// the merge rule can still extend its bottom — so distance has to be attributed backwards.
    /// Keeping every fix would make a 6-hour day a 17,000-element array inside a struct that gets
    /// copied to the UI on every sample. Instead this holds only what a *future* run could still
    /// need, which is one descent plus the lift before it, and `pruneTrail` drops the rest.
    private var trail: [Fix] = []

    /// The earliest instant any run still to be reported could begin at.
    ///
    /// While a descent is pending or in progress that is its own ski start; otherwise it is the top
    /// of the climb currently being tracked, which moves forward on every sample — including on a
    /// stationary day, where the altitude never leaves the plateau band and the buffer would
    /// otherwise grow without bound.
    private var trailKeepFrom: TimeInterval {
        if pendingTopAlt != nil { return pendingSkiFrom }
        if direction == -1 { return legSkiStartTime }
        return plateauEnd
    }

    private mutating func pruneTrail() {
        let keep = trailKeepFrom
        guard let first = trail.first, first.dt < keep else { return }
        // Amortised: only pay for the copy once a meaningful number of fixes have aged out.
        guard let cut = trail.firstIndex(where: { $0.dt >= keep }) else {
            trail.removeAll(keepingCapacity: true)
            return
        }
        if cut >= 256 { trail.removeFirst(cut) }
    }

    /// Distance, own top speed and endpoints for the fixes inside a finished run's window.
    private func measure(from start: TimeInterval, to end: TimeInterval) -> (Double, Double, Fix?, Fix?) {
        var distance = 0.0
        var top = -1.0
        var first: Fix?
        var last: Fix?
        // Distance walks a decimated copy of the window (see `minDistanceDtS`); top speed and the
        // endpoints read every fix, because throwing away 2 of every 3 fixes would also throw away
        // the peak. Two different questions, two different samplings of the same trail.
        var stepFrom: Fix?
        for f in trail where f.dt >= start && f.dt <= end {
            if let prev = stepFrom {
                if f.dt - prev.dt >= Self.minDistanceDtS {
                    distance += Self.haversine(prev.lat, prev.lon, f.lat, f.lon)
                    stepFrom = f
                }
            } else {
                stepFrom = f
            }
            if f.speed > top { top = f.speed }
            if first == nil { first = f }
            last = f
        }
        return (distance, top, first, last)
    }

    /// Great-circle distance in metres. Duplicated from `Tools/analyze.py`'s `haversine` on
    /// purpose — this file takes no dependencies so the replay harness can compile it on a Mac.
    static func haversine(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        let r = 6_371_000.0
        let p1 = aLat * .pi / 180, p2 = bLat * .pi / 180
        let dp = (bLat - aLat) * .pi / 180, dl = (bLon - aLon) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

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
    /// `latitude`/`longitude` are optional so a caller with no position (the unit tests, an older
    /// fixture) still exercises the speed path. A fix inside `maxPositionHAccM` is kept on a short
    /// trail buffer so that when a run finalises, its distance, its own top speed and its endpoints
    /// can be read off the fixes that fell inside it.
    mutating func ingestFix(speed: Double, horizontalAccuracy: Double, speedAccuracy: Double,
                            latitude: Double = .nan, longitude: Double = .nan,
                            at dt: TimeInterval) {
        guard dt >= 0 else { return }

        let speedGated = speed >= 0
            && horizontalAccuracy >= 0 && horizontalAccuracy <= Self.maxSpeedHAccM
            && speedAccuracy >= 0 && speedAccuracy <= Self.maxSpeedAccMS
        if speed >= 0 {
            maxSpeedUngated = max(maxSpeedUngated, speed)
            if speedGated { maxSpeed = max(maxSpeed, speed) }
        }

        guard !latitude.isNaN, !longitude.isNaN,
              horizontalAccuracy >= 0, horizontalAccuracy <= Self.maxPositionHAccM else { return }
        trail.append(Fix(dt: dt, lat: latitude, lon: longitude,
                         speed: speedGated ? speed : -1))
        pruneTrail()
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
        // A merged run is measured from the HIGHER of the two tops (S14). Keeping the first one
        // was wrong when the first was a false top: a lift cresting a roll dips just past the 3 m
        // hysteresis and then climbs higher, so the descent gets declared during the climb and the
        // run starts minutes early. Adopting the higher top takes its ski start with it, because
        // that is the leg whose plateau trim was measured from the real summit.
        if let prevTop = pendingTopAlt,
           topAlt - pendingBotAlt < Self.mergeAscentM,
           topTime - pendingBotTime < Self.mergeGapS {
            if topAlt > prevTop {
                pendingTopAlt = topAlt
                pendingTopTime = topTime
                pendingSkiFrom = skiFrom
            }
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
            let (distance, topSpeed, first, last) = measure(from: pendingSkiFrom, to: pendingBotTime)
            runs.append(Run(startTime: pendingSkiFrom, topTime: pendingTopTime,
                            endTime: pendingBotTime, drop: drop,
                            distanceM: distance, topSpeedMS: topSpeed,
                            startLat: first?.lat ?? .nan, startLon: first?.lon ?? .nan,
                            endLat: last?.lat ?? .nan, endLon: last?.lon ?? .nan))
        } else if drop > 0 {
            subThresholdDropM += drop
        }
        pendingTopAlt = nil
    }
}
