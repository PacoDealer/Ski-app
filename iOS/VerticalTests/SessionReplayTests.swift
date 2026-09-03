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
        #expect(abs(s.descentM - 905) < 0.5, "the corrected day total; 895 was the bug")
        #expect(abs(s.metrics.subThresholdDropM - 12) < 0.5)
        #expect(abs(s.maxSpeedMS * 3.6 - 64.7) < 0.1, "gated: the real peak")
        #expect(abs(s.maxSpeedUngatedMS * 3.6 - 69.6) < 0.1, "ungated: inside the multipath burst")
        #expect(abs(s.skiTime / 60 - 19.9) < 0.1, "after the A19 leading-plateau trim")

        // Slopes' itemised run 1 for this morning was 5m26s and 415 m; ours is 407 m in 5.7 min.
        let first = try #require(s.runs.first)
        #expect(abs(first.drop - 407) < 0.5)
        #expect(abs(first.duration / 60 - 5.7) < 0.1)
    }

    @Test("Session 2, 2026-09-01 — 462 m over 3 runs, the slow afternoon that replicated the result")
    func portilloS2() throws {
        let s = try summarize(Fixtures.portilloS2)

        #expect(s.locCount == 2773)
        #expect(s.staleFixCount == 1)
        #expect(s.dopplerValidCount == 2768, "5 fixes with no valid Doppler")
        #expect(abs(s.hAccMedian - 7.9) < 0.05)

        #expect(s.runs.count == 3, "includes the 38 s surface tow the 60 s minimum used to miss")
        #expect(abs(s.descentM - 462) < 0.5)
        #expect(abs(s.metrics.subThresholdDropM - 24) < 0.5)
        #expect(abs(s.maxSpeedMS * 3.6 - 43.9) < 0.1)
        #expect(s.maxSpeedUngatedMS == s.maxSpeedMS, "a clean session: the gate changes nothing")
        #expect(abs(s.skiTime / 60 - 23.8) < 0.1)
    }

    @Test("The two days together are the day the head-to-head was run on")
    func dayTotal() throws {
        let s1 = try summarize(Fixtures.portilloS1)
        let s2 = try summarize(Fixtures.portilloS2)
        // 1,367 m for the day. Slopes' saved record said 1,380 (+1.0%); Carve's said 1,625 (+18.9%).
        #expect(abs(s1.descentM + s2.descentM - 1367) < 1)
        #expect(abs((s1.skiTime + s2.skiTime) / 60 - 43.7) < 0.2)
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
        let s = try summarize(Fixtures.portilloS3)
        #expect(s.runs.count == 8, "the count the phone should have been showing")
        #expect(abs(s.descentM - 1386) < 1)
        #expect(abs(s.maxSpeedMS * 3.6 - 68.4) < 0.1)
        #expect(s.maxSpeedUngatedMS <= s.maxSpeedMS, "no multipath burst this day — A18's precondition")
        #expect(s.closedCleanly, "the whole file ends on a real end record")

        // Six and a half hours of 25 Hz device motion, most of it with the phone parked and the
        // screen off. The 81-minute dinner control proved this for one hour; this proves it for six.
        #expect(s.imuCount == 597_193)
        #expect(s.imuCoverage > 0.99)
        #expect(s.imuMaxGapS < 2)
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
        #expect(abs(s.descentM - 1386) < 1)
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
