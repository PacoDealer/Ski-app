import Foundation

/// How much of the mountain two descents have in common, and how far apart they were over it.
///
/// **The feature.** Run comparison is the next item on Slopes' Premium list (D7). Slopes answers
/// "are these two descents comparable?" out of a per-resort trail database it pays people to
/// maintain — a run is an atom there, so two descents of it compare trivially. We have no trail
/// database and are not building one, so the answer has to come off the track itself.
///
/// **That is more general, not a compromise.** Because Slopes compares *named runs from its
/// database*, it can compare nothing at a resort it has not mapped and nothing about two descents
/// that only partly overlap. This compares the shared part of any two descents anywhere. It is also
/// the honest unit: S15b established that at Portillo a descent is composed at ski time out of
/// several linked pistes, so "the same run" is often not a fact about the mountain at all.
///
/// **It asserts no names and no identity, because it cannot.** Martin labelled 24 descents and
/// wrote routes rather than piste names. Graded against those labels, separation alone does not
/// separate them and neither does separation plus coverage — same-piste pairs run 11–34 m while
/// different-piste pairs start at 22 m. So nothing here classifies: it reports two numbers and
/// ranks. `Tools/compare.py` is the twin, and carries the grading table.
///
/// Pure Foundation, `nonisolated`, no MapKit — same reasons as `LiveMetrics`: `Tools/replay.sh`
/// compiles it on the Mac, and `SessionReplay` runs it off the main thread.
nonisolated enum RunComparison {

    /// Two descents sharing less altitude than this are not compared at all.
    ///
    /// Reused from `LiveMetrics.minRunDropM` rather than chosen: 30 m is already this project's
    /// answer to "is this enough vertical to be a descent at all", and a shared band smaller than
    /// a whole run is certainly not worth a comparison. No new constant enters the code.
    static var minBandM: Double { LiveMetrics.minRunDropM }

    /// Two descents are offered as comparable when they share at least half of the longer one.
    ///
    /// **A definition, not a fitted threshold — and that distinction is why this is allowed to
    /// ship.** Grading on Portillo says 70% would score better (it takes the same/different overlap
    /// from 17 m to 12 m), and adopting 70% *for that reason* would be fitting a constant to one
    /// resort, on four days, from eight same-piste pairs — exactly what R5 and the S18 shipping bar
    /// forbid. "They share half the descent" is a claim about two runs; "70%" would be a claim
    /// about Portillo. Coverage is shown beside every comparison anyway, so nobody has to trust it.
    static let minCoverage = 0.5

    /// How many altitudes to sample the two descents at. Matches `Tools/compare.py`.
    static let samples = 32

    struct Overlap {
        /// Mean ground distance between the two descents, sampled at shared altitudes.
        let separationM: Double
        /// The altitude band both descents actually cover.
        let sharedM: Double
        /// `sharedM` as a fraction of the **longer** descent, 0…1.
        let coverage: Double
        /// Seconds each descent spent crossing the shared band — **not** its whole duration.
        ///
        /// This is the difference between a shared-segment comparison and a whole-run one wearing
        /// its badge. The first version of this screen printed the two runs' full durations and
        /// announced "faster by 296 s" for a pair sharing 87% of a descent, where a good part of
        /// the gap was time spent outside the band the comparison was scoped to. Comparing over
        /// anything but the shared part is not the feature.
        let secondsA: TimeInterval
        let secondsB: TimeInterval
        /// Whether this pair clears `minCoverage` and is worth putting in front of someone.
        var isComparable: Bool { coverage >= minCoverage }
        /// How much quicker `a` crossed the shared band than `b`. Negative means `a` was faster.
        var deltaSeconds: TimeInterval { secondsA - secondsB }
    }

    /// Where the skier was at each of these absolute altitudes, walking the descent once.
    ///
    /// Altitude is the one coordinate a skier cannot pad: traverse as long as you like, you are
    /// still at 2,900 m when you are at 2,900 m. Sampling there rather than at fractions of each
    /// descent's own track length is what makes this immune to the two bugs S15b found — a slow
    /// descent covering 30% more ground for the same piste, and a descent truncated at a mid-run
    /// stop being stretched to fit.
    ///
    /// **The altitude is GPS, and that is measured rather than assumed (S18).** Everywhere else in
    /// this project the barometer wins; here it loses. Sampling on `CMAbsoluteAltitude` instead
    /// moves same-piste pairs from 11–34 m to 19–43 m and widens the overlap from 12 m to 15 m,
    /// because this needs a coordinate comparable *between days* — a different question from being
    /// precise *within* a run. Paired fix by fix against GPS, the barometer's absolute altitude
    /// sits at −0.2 / +5.4 / +8.1 / +7.4 m on the four recordings: an 8 m swing between days and
    /// 5.6 m between two sessions of one morning. A bias is constant inside a descent, so it never
    /// hurts a top-to-bottom vertical, and it is exactly what ruins registration across descents.
    /// GPS noise averages out over 32 samples; a bias does not.
    static func positions(of points: ArraySlice<SessionTrack.Point>,
                          at altitudes: [Double]) -> [(lat: Double, lon: Double, dt: TimeInterval)] {
        let pts = points.filter { !$0.altitude.isNaN }
        guard pts.count >= 2 else { return [] }
        var out: [(lat: Double, lon: Double, dt: TimeInterval)] = []
        out.reserveCapacity(altitudes.count)
        var j = pts.startIndex
        let last = pts.index(pts.endIndex, offsetBy: -2)
        for target in altitudes {
            while j < last, pts[pts.index(j, offsetBy: 1)].altitude > target {
                j = pts.index(j, offsetBy: 1)
            }
            let a = pts[j], b = pts[pts.index(j, offsetBy: 1)]
            let span = a.altitude - b.altitude
            let f = abs(span) < 1e-9 ? 0 : max(0, min(1, (a.altitude - target) / span))
            // The time is interpolated the same way the position is, so "how long did this descent
            // take to cross the shared band" is answered on the band's own boundaries rather than
            // on whichever fix happened to be nearest.
            out.append((a.lat + (b.lat - a.lat) * f,
                        a.lon + (b.lon - a.lon) * f,
                        a.dt + (b.dt - a.dt) * f))
        }
        return out
    }

    /// Compare two descents over the altitude band they share. `nil` when they share too little.
    static func overlap(_ a: ArraySlice<SessionTrack.Point>,
                        _ b: ArraySlice<SessionTrack.Point>) -> Overlap? {
        let pa = a.filter { !$0.altitude.isNaN }
        let pb = b.filter { !$0.altitude.isNaN }
        guard let aTop = pa.first, let aBot = pa.last,
              let bTop = pb.first, let bBot = pb.last, pa.count >= 2, pb.count >= 2 else {
            return nil
        }

        let top = min(aTop.altitude, bTop.altitude)
        let bottom = max(aBot.altitude, bBot.altitude)
        let band = top - bottom
        guard band >= minBandM else { return nil }

        let targets = (0..<samples).map { top - band * Double($0) / Double(samples - 1) }
        let qa = positions(of: a, at: targets)
        let qb = positions(of: b, at: targets)
        guard qa.count == targets.count, qb.count == targets.count else { return nil }

        let total = zip(qa, qb).reduce(0.0) { $0 + LiveMetrics.haversine($1.0.lat, $1.0.lon,
                                                                        $1.1.lat, $1.1.lon) }
        // Time across the shared band only. `max(0,)` because a descent that briefly climbs back
        // through an altitude can interpolate to a lower dt at the bottom target than the top.
        let secondsA = max(0, (qa.last?.dt ?? 0) - (qa.first?.dt ?? 0))
        let secondsB = max(0, (qb.last?.dt ?? 0) - (qb.first?.dt ?? 0))
        // Against the LONGER descent on purpose. Comparing a 400 m run to the 43 m tail of another
        // scored 13 m of separation and meant nothing; dividing by the shorter one would have
        // called that a perfect match (S18).
        let longer = max(aTop.altitude - aBot.altitude, bTop.altitude - bBot.altitude)
        return Overlap(separationM: total / Double(samples),
                       sharedM: band,
                       coverage: longer > 0 ? band / longer : 0,
                       secondsA: secondsA, secondsB: secondsB)
    }

    /// The descent in `runs` most like `run`, by separation over the shared band.
    ///
    /// Returns the index and the overlap, or `nil` when nothing is comparable. Ranking only —
    /// it never claims the two are the same run, because the grading says it cannot.
    static func closest(to run: LiveMetrics.Run, among runs: [LiveMetrics.Run],
                        in track: SessionTrack) -> (index: Int, overlap: Overlap)? {
        let mine = track.points(in: run)
        guard mine.count >= 2 else { return nil }
        var best: (index: Int, overlap: Overlap)?
        for (i, other) in runs.enumerated() where other.startTime != run.startTime {
            guard let o = overlap(mine, track.points(in: other)), o.isComparable else { continue }
            if best == nil || o.separationM < best!.overlap.separationM {
                best = (i, o)
            }
        }
        return best
    }
}
