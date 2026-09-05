import Foundation
import Testing
@testable import Vertical

/// Run comparison, pinned against `Tools/compare.py` on a real ski day.
///
/// The values here are the Python's to four decimal places, not numbers this suite invented — the
/// same discipline `replay.sh` and `Tools/parity.py` apply to the metrics. If the two ever drift,
/// one of them is wrong and this says so.
@Suite("Comparing two descents")
struct RunComparisonTests {

    /// 2026-09-02: eight runs, several of them the same piste skied repeatedly, which is what makes
    /// it the fixture worth pinning. `s3 r2`, `r3` and `r4` are all "Las Lomas" in Martin's labels.
    private func day() throws -> SessionReplay.Summary {
        try SessionReplay.summarize(Fixtures.portilloS3, collectTrack: true)
    }

    @Test("Separation and coverage match Tools/compare.py on a real day")
    func matchesThePythonTwin() throws {
        let s = try day()
        let runs = s.runs
        #expect(runs.count == 8)

        // r2 ~ r4 — the closest pair of the day, and the same piste by Martin's label.
        let a = try #require(RunComparison.overlap(s.track.points(in: runs[1]),
                                                   s.track.points(in: runs[3])))
        #expect(abs(a.separationM - 13.4468) < 0.01)
        #expect(abs(a.sharedM - 121.0563) < 0.01)
        #expect(abs(a.coverage - 0.9738) < 0.001)
        #expect(a.isComparable)

        // r2 ~ r3, also the same piste.
        let b = try #require(RunComparison.overlap(s.track.points(in: runs[1]),
                                                   s.track.points(in: runs[2])))
        #expect(abs(b.separationM - 14.6554) < 0.01)
        #expect(abs(b.coverage - 0.9808) < 0.001)
    }

    @Test("A thin shared band is not offered, however close the two look over it")
    func coverageIsHalfTheAnswer() throws {
        let s = try day()
        let runs = s.runs

        // r1 is a 300 m descent; r2 is a 125 m one off the same lift. They sit **14.7 m** apart
        // over the slice they share — closer than several genuinely-same-piste pairs — and share
        // only **41%** of the longer one. This is the whole S18 finding in one assertion: a small
        // shared band near a common lift station makes every route look alike, and separation
        // without coverage is meaningless.
        let thin = try #require(RunComparison.overlap(s.track.points(in: runs[0]),
                                                      s.track.points(in: runs[1])))
        #expect(abs(thin.separationM - 15.9068) < 0.01)
        #expect(abs(thin.coverage - 0.4133) < 0.001)
        #expect(!thin.isComparable, "41% of the longer descent is not a comparison")

        // Same first run against r6: nearly the whole descent shared, and further apart over it.
        // Higher separation, but this is the pair a person would actually want to see.
        let full = try #require(RunComparison.overlap(s.track.points(in: runs[0]),
                                                      s.track.points(in: runs[5])))
        #expect(abs(full.coverage - 0.9722) < 0.001)
        #expect(full.isComparable)
        #expect(full.separationM > thin.separationM,
                "the honest comparison scores worse than the meaningless one — hence coverage")
    }

    @Test("The closest comparable descent is ranked, never classified")
    func closestIsARanking() throws {
        let s = try day()
        let runs = s.runs

        let best = try #require(RunComparison.closest(to: runs[1], among: runs, in: s.track))
        #expect(best.index == 3, "r2's nearest comparable descent is r4")
        #expect(best.overlap.isComparable)
        // Every candidate it passed over is either further away or not comparable at all.
        for (i, other) in runs.enumerated() where i != 1 && i != 3 {
            if let o = RunComparison.overlap(s.track.points(in: runs[1]),
                                             s.track.points(in: other)), o.isComparable {
                #expect(o.separationM >= best.overlap.separationM)
            }
        }
    }

    @Test("A descent has nothing to compare against when nothing shares enough altitude")
    func noComparableDescent() throws {
        // The stationary control: no runs at all, so nothing to rank and nothing invented.
        let s = try SessionReplay.summarize(Fixtures.portilloStationary, collectTrack: true)
        #expect(s.runs.isEmpty)
        for run in s.runs {
            #expect(RunComparison.closest(to: run, among: s.runs, in: s.track) == nil)
        }
    }

    @Test("Altitude rides on the track without touching a reported number")
    func altitudeChangesNoMetric() throws {
        // `SessionTrack.Point` gained an altitude in S18. The map and every published figure must
        // be bit-for-bit unchanged by that — same boundary R36b draws for the display transforms.
        let withTrack = try SessionReplay.summarize(Fixtures.portilloS3, collectTrack: true)
        let without = try SessionReplay.summarize(Fixtures.portilloS3)
        #expect(withTrack.descentM == without.descentM)
        #expect(withTrack.descentDistanceM == without.descentDistanceM)
        #expect(withTrack.maxSpeedMS == without.maxSpeedMS)
        #expect(withTrack.runs.count == without.runs.count)
        #expect(without.track.isEmpty, "collection is still opt-in")
        // And the altitudes actually arrived, rather than defaulting to NaN everywhere.
        let pts = withTrack.track.points(in: withTrack.runs[0])
        #expect(pts.allSatisfy { !$0.altitude.isNaN })
    }
}
