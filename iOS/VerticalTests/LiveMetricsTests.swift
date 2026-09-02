import Foundation
import Testing
@testable import Vertical

/// The segmentation and gating rules, each test named after the day it was earned.
///
/// Every rule in `LiveMetrics` exists because a specific wrong number was published — by us or by
/// a competitor — and every one of them is a threshold that a future session could "tidy up"
/// without noticing what it cost. `Tools/replay.sh` proves the Swift agrees with the Python; these
/// prove the rule itself still does what the session that earned it said it should.
@Suite("LiveMetrics — the rules that were paid for")
struct LiveMetricsTests {

    /// Feeds a ramp of altitudes, one sample per second, the way the barometer delivers them.
    private func ramp(_ m: inout LiveMetrics, from: Double, to: Double, startingAt t0: Double,
                      metresPerSecond rate: Double = 1) -> Double {
        let step = from <= to ? rate : -rate
        var alt = from, t = t0
        m.ingestAltitude(alt, at: t)
        while (step > 0 && alt < to) || (step < 0 && alt > to) {
            alt = step > 0 ? min(to, alt + step) : max(to, alt + step)
            t += 1
            m.ingestAltitude(alt, at: t)
        }
        return t
    }

    private func hold(_ m: inout LiveMetrics, at alt: Double, from t0: Double, seconds: Double) -> Double {
        var t = t0
        while t < t0 + seconds {
            t += 1
            m.ingestAltitude(alt, at: t)
        }
        return t
    }

    // MARK: - Speed

    @Test("S5: the speed gate is on horizontal accuracy, and it rejects the multipath burst")
    func speedGate() {
        var m = LiveMetrics()
        m.ingestFix(speed: 18, horizontalAccuracy: 8, speedAccuracy: 2, at: 10)
        #expect(m.maxSpeed == 18)

        // The shape of Carve's published top speed for 2026-09-01: a fast reading whose horizontal
        // accuracy had degraded to ±31 m. Doppler-valid, and still not to be believed.
        m.ingestFix(speed: 42, horizontalAccuracy: 31, speedAccuracy: 2, at: 11)
        #expect(m.maxSpeed == 18, "a fix at ±31 m must not set the day's top speed")
        #expect(m.maxSpeedUngated == 42, "but it must stay visible, or the gap can't be inspected")

        // speedAcc survives only as a loose sanity bound; 5 m/s of uncertainty is not a speed.
        m.ingestFix(speed: 50, horizontalAccuracy: 8, speedAccuracy: 5, at: 12)
        #expect(m.maxSpeed == 18)
    }

    @Test("S6: a fix cached before START must never become the day's top speed")
    func staleFixRejected() {
        var m = LiveMetrics()
        // CoreLocation hands over its last cached fix the instant updates begin — on 2026-09-01 the
        // oldest was 5.9 s before the session started. If that fix was taken in the car on the way
        // up, its Doppler speed is the car's.
        m.ingestFix(speed: 33, horizontalAccuracy: 5, speedAccuracy: 1, at: -5.9)
        #expect(m.maxSpeed == -1)
        #expect(m.maxSpeedUngated == -1, "a pre-start fix is not evidence of anything, gated or not")
    }

    // MARK: - Segmentation

    @Test("S5: a pressure blip must not split a run and lose the tail")
    func descentMergeKeepsTheTail() {
        // The exact shape of the bug: a descent, a 4 m blip at the base building, then 16 m more.
        // Un-merged, the 16 m tail falls under the 30 m minimum and is deleted — which is how we
        // reported 895 m for a 905 m day.
        var m = LiveMetrics()
        var t = ramp(&m, from: 0, to: 200, startingAt: 0)
        t = ramp(&m, from: 200, to: 50, startingAt: t)
        t = ramp(&m, from: 50, to: 54, startingAt: t)
        t = ramp(&m, from: 54, to: 38, startingAt: t)
        m.finish()

        #expect(m.runCount == 1, "one run interrupted by a sensor blip, not two")
        #expect(abs(m.descentM - 162) < 0.001, "top-to-bottom across the blip: 200 → 38")
        #expect(m.subThresholdDropM == 0, "nothing was thrown away")
    }

    @Test("S5: two descents far apart in time are two descents, and the small one is reported")
    func noMergeAcrossALongGap() {
        var m = LiveMetrics()
        var t = ramp(&m, from: 0, to: 200, startingAt: 0)
        t = ramp(&m, from: 200, to: 50, startingAt: t)
        t = hold(&m, at: 50, from: t, seconds: 150)   // a long stop at the bottom
        t = ramp(&m, from: 50, to: 54, startingAt: t)
        t = ramp(&m, from: 54, to: 38, startingAt: t)
        m.finish()

        #expect(m.runCount == 1)
        #expect(abs(m.descentM - 150) < 0.001)
        // The 16 m is genuinely not a run — but it is never *silently* dropped. A day that loses a
        // lot here is a day the thresholds are wrong for that mountain, and only this number says so.
        #expect(abs(m.subThresholdDropM - 16) < 0.001)
    }

    @Test("S12: the live RUNS tile counts the same descents the live VERTICAL tile adds up")
    func liveTilesAgreeBeforeTheSessionEnds() {
        // The 2026-09-02 bug, in the shape that produced it: ski runs, then stop skiing and leave
        // the session open. The last descent stays in `pending` — mergeable until something closes
        // it — so `provisionalDescentM` counted it while `runCount` did not, and the phone sat all
        // afternoon reading 7 runs / 1,386 m where a replay of the same bytes read 8 / 1,386.
        var m = LiveMetrics()
        var t: TimeInterval = 0
        for _ in 0..<3 {
            t = ramp(&m, from: 0, to: 200, startingAt: t)
            t = ramp(&m, from: 200, to: 0, startingAt: t)
        }
        _ = hold(&m, at: 0, from: t, seconds: 600)   // the break: session still open, no STOP

        // Live, mid-session — no `finish()`, which is the whole point.
        #expect(m.provisionalRunCount == 3, "three descents skied, three on the tile")
        #expect(abs(m.provisionalDescentM - 600) < 0.001)
        // Two descents are outstanding at the bottom of the last run — one closed into `pending`,
        // one whose leg has not turned around yet — so the tile was *two* behind, not one.
        #expect(m.runCount == 1, "only the first descent is a settled, completed run")

        // And ending the session must not change what the screen was already claiming.
        m.finish()
        #expect(m.runCount == 3)
        #expect(m.provisionalRunCount == 3, "STOP settles the count, it does not move it")
        #expect(abs(m.descentM - 600) < 0.001)
    }

    @Test("S7/A19: a run starts when the skier pushes off, not when the altitude stops rising")
    func runStartsAfterThePlateau() {
        // Slopes graded us on this for free: our ski time read +33% high because a minute spent
        // standing at the top counted as run time. Vertical must not move — only the clock.
        var m = LiveMetrics()
        var t = ramp(&m, from: 0, to: 100, startingAt: 0)   // arrives at the top at t = 100
        t = hold(&m, at: 100, from: t, seconds: 60)          // stands there for a minute
        _ = ramp(&m, from: 100, to: 0, startingAt: t)
        m.finish()

        let run = try! #require(m.runs.first)
        #expect(m.runCount == 1)
        #expect(abs(run.drop - 100) < 0.001, "trimming the wait must not change the vertical")
        #expect(abs(run.topTime - 100) < 1.5, "the altitude turning point is still the top")
        #expect(run.startTime >= 158, "the 60 s spent standing at the top is not run time")
        #expect(run.duration < 105, "≈100 s of skiing, not the 160 s from the turning point")
    }

    @Test("S4: a descent that straddles a resume seam is abandoned, never measured across it")
    func resumeSeamDoesNotInventVertical() {
        // `CMAltimeter.relativeAltitude` restarts from zero every time updates begin. Summing
        // across that seam is how a 400 m descent was once reported as 800 m.
        var m = LiveMetrics()
        var t = ramp(&m, from: 0, to: 400, startingAt: 0)
        t = ramp(&m, from: 400, to: 200, startingAt: t)      // half-way down when the app dies

        m.beginAltitudeSegment()                              // baseline restarts at zero

        t = ramp(&m, from: 0, to: -100, startingAt: t + 30)
        m.finish()

        #expect(m.runCount == 1, "only the descent recorded wholly after the seam is measurable")
        #expect(abs(m.descentM - 100) < 0.001,
                "the 200 m in flight at the seam has an unknown size, and an unknown is not guessed")
    }

    @Test("Noise under the hysteresis floor is not a run")
    func baroNoiseIsNotARun() {
        var m = LiveMetrics()
        var t = 0.0
        for i in 0..<300 {
            m.ingestAltitude(2880 + sin(Double(i) / 3) * 1.2, at: t)
            t += 1
        }
        m.finish()
        #expect(m.runCount == 0)
        #expect(m.descentM == 0)
    }
}
