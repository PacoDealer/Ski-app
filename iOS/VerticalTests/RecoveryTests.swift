import Foundation
import Testing
@testable import Vertical

/// The two things that stand between a crash and a lost ski day.
///
/// `SessionRecovery` decides whether the app silently picks a recording back up, and `SampleWriter`
/// decides whether reopening that file appends to it or erases it. Both have already been wrong
/// once, both fail silently when they are, and neither has any symptom until the evening — which
/// is exactly the profile of a thing that needs a test rather than a careful reader.
@Suite("Not losing the day")
struct RecoveryTests {

    private let started = Date(timeIntervalSince1970: 1_788_000_000)

    // MARK: - SessionRecovery

    @Test("A session that ended cleanly is left alone")
    func cleanSessionIsNotResumed() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                  startedAt: started, lastDt: 3600, closed: true)
        #expect(SessionRecovery.findInterrupted(in: dir,
                                                now: started.addingTimeInterval(3700)) == nil)
    }

    @Test("A session that died minutes ago is resumed, with its counts intact")
    func recentCrashIsResumed() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                  startedAt: started, lastDt: 3600, locs: 7, marks: 2, closed: false)

        let found = try #require(SessionRecovery.findInterrupted(
            in: dir, now: started.addingTimeInterval(3600 + 300)))
        #expect(found.locCount == 7)
        #expect(found.markCount == 2)
        #expect(found.startedAt == started, "resumed samples keep counting dt from the original start")
        #expect(abs(found.lastSampleAt.timeIntervalSince(started) - 3600) < 0.001)
    }

    @Test("The 6-hour window: a dead battery over lunch is resumed, yesterday is not")
    func resumeWindow() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                  startedAt: started, lastDt: 3600, closed: false)
        let died = started.addingTimeInterval(3600)

        // The two mistakes are not symmetric: resuming wrongly costs one press of STOP, failing to
        // resume costs an afternoon that cannot be re-skied. So the window is deliberately generous.
        #expect(SessionRecovery.findInterrupted(
            in: dir, now: died.addingTimeInterval(5.9 * 3600)) != nil)
        #expect(SessionRecovery.findInterrupted(
            in: dir, now: died.addingTimeInterval(6.1 * 3600)) == nil)
    }

    @Test("An old crash under a clean newer session stays buried")
    func onlyTheNewestFileCounts() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        try Fixtures.writeSession(in: dir, named: "2026-08-30_100000_AAAAAAAA.jsonl",
                                  startedAt: started.addingTimeInterval(-172_800),
                                  lastDt: 60, closed: false)
        try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_BBBBBBBB.jsonl",
                                  startedAt: started, lastDt: 3600, closed: true)
        #expect(SessionRecovery.findInterrupted(in: dir,
                                                now: started.addingTimeInterval(3700)) == nil,
                "an ancient unterminated file is an old crash, not today's")
    }

    @Test("S4: the `end` probe tolerates whitespace it will never see from our own encoder")
    func endProbeIsForgiving() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        // A file from anywhere else — a Python re-export, a hand edit — with a space after the
        // colon. Being strict here buys nothing and costs a resume that should never happen.
        let url = try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                            startedAt: started, lastDt: 60, closed: false)
        let spaced = #"{"t": "end", "dt": 60, "locCount": 3, "baroCount": 1, "imuCount": 0}"# + "\n"
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(spaced.utf8))
        try handle.close()

        #expect(SessionRecovery.findInterrupted(in: dir,
                                                now: started.addingTimeInterval(120)) == nil)
    }

    // MARK: - SampleWriter

    @Test("S4: reopening a recording appends to it — `createFile` truncates")
    func reopeningDoesNotTruncate() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        let url = try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                            startedAt: started, lastDt: 600, locs: 5, closed: false)
        let before = try Data(contentsOf: url).count

        // Exactly what crash recovery does on next launch. If this ever truncates again, it erases
        // the recording it was opened to rescue.
        let writer = try SampleWriter(url: url)
        writer.write(NoteSample(dt: 601, text: "resumed after interruption"))
        writer.close()

        let after = try Data(contentsOf: url)
        #expect(after.count > before, "the file grew rather than being replaced")
        let text = try #require(String(data: after, encoding: .utf8))
        #expect(text.contains("resumed after interruption"))

        let s = try SessionReplay.summarize(url)
        #expect(s.locCount == 5, "every sample from before the crash is still there")
        #expect(s.resumeSeams == 1)
    }

    @Test("A power cut mid-write leaves a torn line, and the next record does not glue onto it")
    func tornFinalLineIsClosedOff() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { Fixtures.remove(dir) }
        let url = try Fixtures.writeSession(in: dir, named: "2026-09-01_100000_AAAAAAAA.jsonl",
                                            startedAt: started, lastDt: 600, locs: 4, closed: false)

        // Chop the trailing newline: what a fsync interrupted by a flat battery leaves behind.
        var data = try Data(contentsOf: url)
        data.removeLast(20)
        try data.write(to: url)

        let writer = try SampleWriter(url: url)
        writer.write(NoteSample(dt: 601, text: "resumed after interruption"))
        writer.close()

        // The torn remnant stays as one unparseable line and is skipped; the new record is intact.
        let s = try SessionReplay.summarize(url)
        #expect(s.resumeSeams == 1, "the appended note parsed, so it was not glued onto the remnant")
        #expect(s.locCount >= 3, "only the sample that was being written is lost")
    }
}
