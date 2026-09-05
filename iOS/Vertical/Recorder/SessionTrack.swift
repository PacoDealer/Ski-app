import Foundation

/// The line on the ground: where the skier actually went, and how fast at each point.
///
/// **Why this is separate from `LiveMetrics`.** The metrics engine is a *streaming* summariser —
/// it keeps a run's endpoints and throws the middle away, which is exactly right for a live tile
/// on a phone in a pocket for seven hours. A map needs the middle. So the track is collected on
/// the same single parse of the file (`SessionReplay.summarize(_:collectTrack:)`) but kept in its
/// own type, and no metric is ever derived from it — R12a's "one rule, one implementation" is
/// about rules, and this is raw data, not a rule. Nothing here decides anything.
///
/// **Cost, stated rather than assumed:** a 7 h day is ~23,000 usable fixes at 40 bytes each, so
/// under 1 MB. Collection is opt-in anyway, so the recorder and `Tools/replay.sh` never pay it.
///
/// **Pure Foundation on purpose** — no MapKit, no CoreLocation — so it stays testable on the Mac
/// alongside the rest of `Recorder/`.
nonisolated struct SessionTrack {

    /// One fix worth drawing: inside `LiveMetrics.maxPositionHAccM`, with its Doppler speed if
    /// that speed passed the same gate the headline uses.
    struct Point {
        let dt: TimeInterval
        let lat: Double
        let lon: Double
        /// Gated Doppler ground speed in m/s, or negative when this fix carried none. **Negative
        /// is not zero** — an ungated fix is unknown, and colouring it as "slow" would invent a
        /// stopped skier out of a missing field.
        let speedMS: Double
        /// Raw `CLLocation.altitude`, metres. **GPS on purpose, and not the barometer** — see
        /// `RunComparison`, which is the only thing that reads it. The barometer is the better
        /// sensor for a difference inside one descent and the worse one for registering two
        /// descents against each other, because its offset moves with the weather (measured at
        /// −0.2 to +8.1 m across the four recordings, S18). Never use this for vertical.
        let altitude: Double

        /// Altitude defaults to "unknown" rather than to a number. A missing GPS altitude is not
        /// sea level, and `RunComparison` drops NaN points instead of registering two descents
        /// against a fix that never carried one.
        init(dt: TimeInterval, lat: Double, lon: Double,
             speedMS: Double, altitude: Double = .nan) {
            self.dt = dt
            self.lat = lat
            self.lon = lon
            self.speedMS = speedMS
            self.altitude = altitude
        }
    }

    private(set) var points: [Point] = []

    var isEmpty: Bool { points.isEmpty }

    mutating func append(dt: TimeInterval, lat: Double, lon: Double, altitude: Double = .nan,
                         speed: Double, horizontalAccuracy: Double, speedAccuracy: Double) {
        guard !lat.isNaN, !lon.isNaN,
              horizontalAccuracy >= 0, horizontalAccuracy <= LiveMetrics.maxPositionHAccM
        else { return }
        // The same speed gate as the headline (S5: hAcc is the field that fails, `speedAcc` is a
        // loose sanity bound). A fix good enough to draw is not automatically good enough to
        // colour, and this is where those two questions are kept apart.
        let gated = speed >= 0
            && horizontalAccuracy <= LiveMetrics.maxSpeedHAccM
            && speedAccuracy >= 0 && speedAccuracy <= LiveMetrics.maxSpeedAccMS
        points.append(Point(dt: dt, lat: lat, lon: lon,
                            speedMS: gated ? speed : -1, altitude: altitude))
    }

    /// The points of one run, by the run's own time window.
    ///
    /// Uses `startTime`, not `topTime`, so the map shows the same descent the numbers describe —
    /// the wait at the top is excluded from both (S7/A19), and S17 confirmed those leading seconds
    /// are traversing rather than skiing (`Tools/runup.py`).
    func points(in run: LiveMetrics.Run) -> ArraySlice<Point> {
        points(from: run.startTime, to: run.endTime)
    }

    func points(from start: TimeInterval, to end: TimeInterval) -> ArraySlice<Point> {
        // `points` is append-ordered by `dt`, so both ends are a binary search.
        let lo = lowerBound(start)
        let hi = lowerBound(end.nextUp)
        return lo <= hi ? points[lo..<hi] : points[lo..<lo]
    }

    private func lowerBound(_ dt: TimeInterval) -> Int {
        var lo = 0, hi = points.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].dt < dt { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Drop fixes that did not move far enough to be worth drawing.
    ///
    /// **The map was a string of blobs before this, and the cause was real data rather than a
    /// rendering bug:** wherever the skier is slow or standing — the top of a pitch, a traverse,
    /// the lift queue — 1 Hz fixes pile twenty deep inside a few metres, and twenty overlapping
    /// round-capped line segments paint a disc. Keeping only the points that actually moved draws
    /// the same line without the pile-ups.
    ///
    /// It is the display twin of `LiveMetrics.minDistanceDtS`, which decimates for the same reason
    /// on the measurement side (S14b) — and like that one it changes no number, because nothing is
    /// ever measured from the result. 8 m is just above these recordings' median ±8 m horizontal
    /// accuracy, so what goes is scatter rather than travel. First and last points always survive.
    static func thinned(_ pts: [Point], minStepM: Double = 8) -> [Point] {
        guard let first = pts.first else { return [] }
        var out = [first]
        for p in pts.dropFirst() {
            let last = out[out.count - 1]
            if LiveMetrics.haversine(last.lat, last.lon, p.lat, p.lon) >= minStepM {
                out.append(p)
            }
        }
        // "First and last always survive" was not quite true: an `out.count > 1` guard here also
        // dropped the last point whenever *every* point sat within `minStepM` of the first, which
        // is a short slow run rather than an impossible input. The `dt` test below is the only one
        // needed — it already covers the single-point case, where first and last are the same fix.
        if let last = pts.last, out[out.count - 1].dt != last.dt {
            out.append(last)
        }
        return out
    }

    /// Speeds for COLOURING ONLY, smoothed with a rolling median over ±2 samples (~±2 s at 1 Hz).
    ///
    /// **This never touches a reported number.** Top speed, average speed and distance all come
    /// from `LiveMetrics` on the raw gated fixes, and must — smoothing is exactly what we measured
    /// Slopes doing to its top speed (+3.59%, A18) and criticised Carve for doing to its altitude.
    /// This is the display layer, and the thing being fixed is a drawing artifact: raw 1 Hz Doppler
    /// crosses a colour-band boundary almost every second, so a five-band ramp painted straight
    /// off it produces two-point segments whose round line caps render the track as a string of
    /// blobs rather than a line. A median (not a mean) keeps a real acceleration sharp while
    /// dropping the single-sample jitter, and it cannot invent a value the skier did not record.
    ///
    /// Unknown speeds stay unknown: a negative input stays negative and is never filled in from
    /// its neighbours.
    static func displaySpeeds<S: Sequence>(_ points: S) -> [Double] where S.Element == Point {
        let raw = points.map(\.speedMS)
        guard raw.count > 4 else { return raw }
        return raw.indices.map { i in
            guard raw[i] >= 0 else { return -1 }
            let lo = max(0, i - 2), hi = min(raw.count - 1, i + 2)
            let window = raw[lo...hi].filter { $0 >= 0 }.sorted()
            return window.isEmpty ? -1 : window[window.count / 2]
        }
    }

    /// The speed range to colour against, in m/s, from the gated fixes of the given points.
    ///
    /// **Percentiles, not min/max (R25's lesson at the display layer).** One multipath second owns
    /// a min/max range and flattens every real difference on the map into a single colour — which
    /// is the same failure that let a 4 s burst become Carve's published top speed. The 5th/95th
    /// percentiles are stable against that, and the two clamped tails still draw at the ramp ends.
    /// Returns nil when nothing in range carried a gated speed.
    static func speedRange<S: Sequence>(_ points: S) -> (lo: Double, hi: Double)?
    where S.Element == Point {
        var speeds = points.compactMap { $0.speedMS >= 0 ? $0.speedMS : nil }
        guard speeds.count >= 2 else { return nil }
        speeds.sort()
        let lo = speeds[speeds.count * 5 / 100]
        let hi = speeds[min(speeds.count - 1, speeds.count * 95 / 100)]
        // A run skied at a near-constant speed is a real thing; give it a floor so the ramp does
        // not amplify 2 km/h of noise into the full colour range.
        guard hi - lo >= 1.0 else { return nil }
        return (lo, hi)
    }
}
