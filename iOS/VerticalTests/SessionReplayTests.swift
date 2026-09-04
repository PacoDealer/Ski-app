import Foundation
import Testing
@testable import Vertical

/// Golden numbers for the two real Portillo days.
///
/// These are the whole point of keeping raw files. Every figure below has been checked against
/// `Tools/analyze.py`, printed in `ROADMAP.md`, and in several cases compared on the mountain
/// against Slopes and Carve. If a threshold moves, this suite says exactly which day it moved and
/// by how much — instead of a session six weeks from now quietly publishing a different history.
///
/// A failure here is not automatically a bug. It means the day's number changed, which is a claim
/// that needs a session log entry and a reason.
@Suite("The Portillo days, replayed")
struct SessionReplayTests {

    private func summarize(_ url: URL) throws -> SessionReplay.Summary {
        try #require(FileManager.default.fileExists(atPath: url.path),
                     "fixture missing at \(url.path) — tests read Data/fixtures in the repo")
        return try SessionReplay.summarize(url)
    }

    @Test("Session 1, 2026-09-01 — 905 m over 4 runs, and a 64.7 km/h peak that is not the glitch")
    func portilloS1() throws {
        let s = try summarize(Fixtures.portilloS1)

        #expect(s.locCount == 3342, "one pre-start cached fix is excluded, as analyze.py does")
        #expect(s.staleFixCount == 1)
        #expect(s.baroCount == 3071)
        #expect(s.dopplerValidCount == 3342, "Doppler was valid on every fix outdoors")
        #expect(abs(s.hAccMedian - 8.0) < 0.05)
        #expect(s.closedCleanly)
        #expect(s.resumeSeams == 0)

        #expect(s.runs.count == 4)
        #expect(abs(s.descentM - 898) < 0.5, "905 until S16 trimmed the dead runout off each run")
        #expect(abs(s.metrics.subThresholdDropM - 12) < 0.5)
        #expect(abs(s.maxSpeedMS * 3.6 - 64.7) < 0.1, "gated: the real peak")
        #expect(abs(s.maxSpeedUngatedMS * 3.6 - 69.6) < 0.1, "ungated: inside the multipath burst")
        #expect(abs(s.skiTime / 60 - 17.6) < 0.1, "after the A19 leading and the S16 trailing trim")

        // Slopes' itemised run 1 for this morning was 5m26s and 415 m; ours is 407 m in 5.7 min.
        let first = try #require(s.runs.first)
        #expect(abs(first.drop - 406) < 0.5)
        #expect(abs(first.duration / 60 - 4.9) < 0.1)
    }

    @Test("Session 2, 2026-09-01 — 462 m over 3 runs, the slow afternoon that replicated the result")
    func portilloS2() throws {
        let s = try summarize(Fixtures.portilloS2)

        #expect(s.locCount == 2773)
        #expect(s.staleFixCount == 1)
        #expect(s.dopplerValidCount == 2768, "5 fixes with no valid Doppler")
        #expect(abs(s.hAccMedian - 7.9) < 0.05)

        #expect(s.runs.count == 3, "includes the 38 s surface tow the 60 s minimum used to miss")
        #expect(abs(s.descentM - 459) < 0.5)
        #expect(abs(s.metrics.subThresholdDropM - 24) < 0.5)
        #expect(abs(s.maxSpeedMS * 3.6 - 43.9) < 0.1)
        #expect(s.maxSpeedUngatedMS == s.maxSpeedMS, "a clean session: the gate changes nothing")
        #expect(abs(s.skiTime / 60 - 19.1) < 0.1)
    }

    @Test("The two days together are the day the head-to-head was run on")
    func dayTotal() throws {
        let s1 = try summarize(Fixtures.portilloS1)
        let s2 = try summarize(Fixtures.portilloS2)
        // 1,367 m for the day. Slopes' saved record said 1,380 (+1.0%); Carve's said 1,625 (+18.9%).
        #expect(abs(s1.descentM + s2.descentM - 1357) < 1)
        #expect(abs((s1.skiTime + s2.skiTime) / 60 - 36.7) < 0.2)
    }

    @Test("The negative control: 81 stationary minutes produce no runs and no vertical")
    func stationaryDinnerInventsNothing() throws {
        // Recorded over dinner on 2026-09-01 to test background motion capture, and it turned into
        // the control the project had never run: every accuracy claim until now was "our number is
        // close to Slopes'", never "our number is zero when nothing happened".
        let s = try summarize(Fixtures.portilloStationary)
        #expect(s.runs.isEmpty)
        #expect(s.descentM == 0)
        #expect(s.metrics.subThresholdDropM == 0, "not even a sub-threshold descent")
        #expect(s.maxSpeedMS * 3.6 < 5, "a phone on a table is not moving")

        // The same data through the GPS-summing method every other app uses gives 674 m — see
        // ROADMAP S10. This assertion is the whole product in one line.
        #expect(s.imuCount == 122_358)
        #expect(s.imuCoverage > 0.99, "background device motion, observed rather than inferred")
        #expect(s.imuMaxGapS < 2, "no gap while the phone was locked in a pocket")
    }

    @Test("2026-09-02: eight runs, and the IMU held for six and a half hours")
    func portilloS3() throws {
        // The four-app day. At 12:46 the phone's own screen read 7 runs / 1,386 m; replaying the
        // same bytes reads 8 / 1,386, which is how the provisional-run-count bug was found. The
        // vertical was never wrong — only the count — so this fixture pins both.
        //
        // S14 moved the vertical 1,386 -> 1,390: this is the one day of the three with false tops,
        // and the higher-top merge rule measures its runs 6-8 from the real summit. Slopes reads
        // 1,359.9 for the same day, so the 4 m moved us 1.9% -> 2.2% away from it while halving
        // the run-start error (56 s -> 29 s). See `Tools/falsetop.py`.
        let s = try summarize(Fixtures.portilloS3)
        #expect(s.runs.count == 8, "the count the phone should have been showing")
        #expect(abs(s.descentM - 1368) < 1)
        #expect(abs(s.maxSpeedMS * 3.6 - 68.4) < 0.1)
        #expect(s.maxSpeedUngatedMS <= s.maxSpeedMS, "no multipath burst this day — A18's precondition")
        #expect(s.closedCleanly, "the whole file ends on a real end record")

        // Six and a half hours of 25 Hz device motion, most of it with the phone parked and the
        // screen off. The 81-minute dinner control proved this for one hour; this proves it for six.
        #expect(s.imuCount == 597_193)
        #expect(s.imuCoverage > 0.99)
        #expect(s.imuMaxGapS < 2)
    }

    @Test("2026-09-03: nine runs, and the gate throws away a 78 km/h burst")
    func portilloS4() throws {
        let s = try summarize(Fixtures.portilloS4)
        #expect(s.runs.count == 9, "Slopes itemises 8 — we split its run 2, and the halves sum to +0.7%")
        #expect(abs(s.descentM - 1365) < 1)
        #expect(s.closedCleanly)

        // The speed gate, doing the one job it exists for. At 17:16:56 — after the last run, with
        // the phone off the snow — four fixes report 78.4 km/h with `speedAcc` invalid and hAcc
        // degrading 12 -> 20 m. Ungated, that burst is the day's headline. Gated, the day peaks at
        // 67.0 km/h, which is *bit-for-bit* the maximum in Slopes' own RawGPS.csv for the same day
        // (66.999 km/h @ 12:57:16.999, hAcc ±7.9). Slopes published 69.1 — its own smoothing of the
        // same clean fix, +3.2%, in line with the +2.7% mean measured on 2026-09-01. Neither app
        // published the burst; that is A18, confirmed a second time and this time on a burst day.
        #expect(abs(s.maxSpeedMS * 3.6 - 67.0) < 0.1)
        #expect(s.maxSpeedUngatedMS * 3.6 > 78, "the burst is really in the file")

        #expect(s.imuCount == 489_904)
        #expect(s.imuCoverage > 0.99)
        #expect(s.imuMaxGapS < 2)
    }

    @Test("Per-run distance and top speed, graded against Slopes' own export")
    func perRunDistanceAndTopSpeed() throws {
        // Golden numbers for the run-by-run stats added in S14, pinned on the best-graded day.
        // These are not "whatever the code printed": every one is scored against
        // `3 September 2026 - Portillo.slopes` by `Tools/grade.py`, and the day distance below
        // sat +4.3% over Slopes' 10.09 km until S16, because our runs kept a runout Slopes cuts.
        // That tail is now trimmed when the skier has stopped both descending and moving, and the
        // day reads 10.35 km, +2.5%. The residual is measurement, not segmentation: over Slopes'
        // OWN run windows our distance is +0.1% across 23 runs (`Tools/runout.py`).
        let s = try summarize(Fixtures.portilloS4)
        #expect(abs(s.descentDistanceM - 10_350) < 20)

        // Run 4 is the short pitch that carries the day's top speed. Its own top speed must equal
        // the day's, which is the check that per-run speed reads the same gated stream as the
        // headline rather than a second opinion.
        let run4 = s.runs[3]
        #expect(abs(run4.topSpeedMS - s.maxSpeedMS) < 0.001)
        #expect(abs(run4.distanceM - 394) < 5)
        #expect(run4.averageSpeedMS * 3.6 > 15, "a 57 m pitch in 84 s is not a traverse")

        // Every run must carry a distance and endpoints, or the comparison work built on top of
        // this has silent holes in it.
        for (i, r) in s.runs.enumerated() {
            #expect(r.distanceM > 0, "run \(i + 1) has no distance")
            #expect(r.hasPosition, "run \(i + 1) has no endpoints")
            #expect(r.topSpeedMS >= 0, "run \(i + 1) has no top speed")
            #expect(r.topSpeedMS <= s.maxSpeedMS, "no run may beat the day")
        }
    }

    @Test("Summing every 1 Hz fix inflates distance — the decimation is load-bearing")
    func distanceDecimationMatters() throws {
        // The guard R22 asks for. Distance summed fix-by-fix reads +9.8% against Slopes across
        // three days, so this asserts the two methods actually differ on real data: if a future
        // change quietly drops `minDistanceDtS`, the day distance moves by ~7% and this fails
        // rather than silently reintroducing the category bug we exist to criticise.
        let s = try summarize(Fixtures.portilloS4)
        var naive = 0.0
        for r in s.runs {
            // Straight-line lower bound per run; the real fix-by-fix sum is larger still.
            naive += LiveMetrics.haversine(r.startLat, r.startLon, r.endLat, r.endLon)
        }
        #expect(naive > 0)
        #expect(s.descentDistanceM > naive,
                "a run's path is longer than its chord — distance is following the track")
        #expect(LiveMetrics.minDistanceDtS > 1.0,
                "at 1 Hz a step per fix is scatter-dominated; see the S14 sweep")
    }

    @Test("The 40 MB devicectl prefix reads the same day as the whole file")
    func fortyMegabytePrefixReadsTheSameDay() throws {
        // S12 analysed this day from a 40,000,000-byte truncation, because `devicectl copy from`
        // stops there and reports it as a socket error (R18a). S13 got the whole 49,716,710-byte
        // file off by AirDrop. The capture format is append-only and fsync'd, so a mid-recording
        // copy is supposed to be a valid prefix — this is the test of that claim, and it is what
        // licenses pulling a file off the phone without waiting for STOP (R18b).
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        let whole = try Data(contentsOf: Fixtures.portilloS3)
        let url = dir.appendingPathComponent("2026-09-02_102227_2BBEACBF.jsonl")
        try whole.prefix(Fixtures.devicectlPrefixBytes).write(to: url)

        let s = try SessionReplay.summarize(url)
        #expect(s.runs.count == 8)
        #expect(abs(s.descentM - 1368) < 1)
        #expect(abs(s.maxSpeedMS * 3.6 - 68.4) < 0.1)
        #expect(!s.closedCleanly, "a prefix has no end record — and is summarised anyway")
    }

    @Test("v1 files still parse after the format-2 motion records were added")
    func formatVersionOneStillReads() throws {
        let s = try summarize(Fixtures.portilloS1)
        #expect(s.formatVersion == 1)
        #expect(s.imuCount == 0)
        #expect(s.imuMaxGapS == -1, "no motion at all is not a motion gap")
    }

    @Test("An interrupted file is summarised, not refused")
    func interruptedFileStillSummarises() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        let url = try Fixtures.writeSession(in: dir, named: "2026-09-02_090000_ABCDEFGH.jsonl",
                                            startedAt: Date(), lastDt: 600, closed: false)
        let s = try SessionReplay.summarize(url)
        #expect(!s.closedCleanly)
        #expect(s.locCount == 3, "a file with no end record is still a perfectly valid recording")
    }
}
