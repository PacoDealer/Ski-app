import Foundation
@testable import Vertical

/// Test support: the two real Portillo recordings, and a way to build session files that are
/// **byte-identical to production output**.
///
/// That second part is the S4 lesson written down as code. A hand-rolled `json.dumps` fixture put a
/// space after the colon, a `"t":"end"` probe silently missed it, and the test proved only that the
/// fixture was wrong. So every synthetic session here is written through the real `SampleWriter`
/// with the real sample structs — if the wire format changes, these files change with it.
enum Fixtures {

    // MARK: - The real days

    /// Repository root, resolved from this file's own compile-time path.
    ///
    /// The fixtures are 2 MB each and are the project's most valuable artefact; copying them into
    /// a test bundle would mean two copies that can drift. Tests run on the simulator, which shares
    /// the Mac's filesystem, so the originals can be read where they live.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)          // iOS/VerticalTests/Fixtures.swift
            .deletingLastPathComponent()          // iOS/VerticalTests
            .deletingLastPathComponent()          // iOS
            .deletingLastPathComponent()          // repo root
    }

    static func day(_ name: String) -> URL {
        repoRoot.appendingPathComponent("Data/fixtures/\(name).jsonl")
    }

    static let portilloS1 = day("2026-09-01_portillo_s1")
    static let portilloS2 = day("2026-09-01_portillo_s2")

    // MARK: - Synthetic sessions, written the way the app writes them

    /// A scratch directory that cleans itself up.
    static func makeTempDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VerticalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func remove(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Writes one session file through the real writer.
    ///
    /// - Parameters:
    ///   - startedAt: goes into the `meta` header; `SessionRecovery` adds `dt` to it to work out
    ///     when recording actually died.
    ///   - lastDt: seconds from the header to the final sample.
    ///   - closed: whether to append an `end` record. `false` is a crash, a jetsam kill, or a flat
    ///     battery — the case the whole recovery path exists for.
    @discardableResult
    static func writeSession(in directory: URL,
                             named name: String,
                             startedAt: Date,
                             lastDt: TimeInterval,
                             locs: Int = 3,
                             marks: Int = 0,
                             closed: Bool) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let writer = try SampleWriter(url: url)
        writer.write(MetaSample(startedAt: startedAt,
                                bootTimeRef: 0,
                                sessionID: "TESTTEST-0000-0000-0000-000000000000",
                                device: "iPhone18,3",
                                osVersion: "26.6.1",
                                appVersion: "0.1",
                                formatVersion: SampleWriter.formatVersion))
        for i in 0..<locs {
            writer.write(LocSample(dt: lastDt * Double(i) / Double(max(locs, 1)),
                                   ts: startedAt, lat: -32.83, lon: -70.12,
                                   alt: 2880, ellAlt: 2900, hAcc: 8, vAcc: 4,
                                   speed: 5, speedAcc: 1, course: 90, courseAcc: 5))
        }
        for i in 0..<marks {
            writer.write(MarkSample(dt: Double(i), label: "Top"))
        }
        writer.write(BaroSample(dt: lastDt, relAlt: -120, pressure: 71.5))
        if closed {
            writer.write(EndSample(dt: lastDt, locCount: locs, baroCount: 1, imuCount: 0))
        }
        writer.close()
        return url
    }
}
