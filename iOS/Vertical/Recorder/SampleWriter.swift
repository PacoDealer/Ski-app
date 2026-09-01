import Foundation

/// Append-only JSONL writer for one recording session.
///
/// Design constraint, straight out of the research: **losing a ski day is unrecoverable and
/// personal.** The 1★ reviews of every competitor in this category are data loss — recordings that
/// silently stopped, watches that died, "resume or finish?" prompts that tripled run totals.
///
/// So: every sample is written to the file descriptor the moment it arrives, and `fsync`'d
/// periodically. There is no in-memory buffer to lose. A crash, a force-quit, or a dead battery
/// costs at most the last few samples, and the file left on disk is always a valid partial
/// recording that the app can pick up silently on next launch — never by asking Martin a question
/// he can get wrong.
/// `@unchecked Sendable` is honest here rather than lazy: every mutable member is touched only
/// from `queue`, and `queue` is serial.
nonisolated final class SampleWriter: @unchecked Sendable {

    /// Bumped whenever the on-disk format changes, so old recordings stay readable.
    /// 2 — added the `imu` record and `end.imuCount` (S8). Purely additive: a reader that buckets
    /// by `t` gains a bucket and loses nothing, so the two Portillo fixtures stay valid at v1.
    static let formatVersion = 2

    private let queue = DispatchQueue(label: "com.gamberg.vertical.writer", qos: .utility)
    private let handle: FileHandle
    private let encoder: JSONEncoder
    let url: URL

    /// Samples written since the last fsync.
    private var sinceSync = 0
    /// Force durability every N samples. At ~1 Hz this is roughly every 20s — cheap, and bounds
    /// worst-case loss on abrupt power failure to a handful of samples.
    private let syncEvery = 20

    /// Opens `url` for appending, creating it only if it isn't already there.
    ///
    /// The "only if absent" part is load-bearing: `createFile` truncates an existing file, so
    /// creating unconditionally would erase the very recording that crash recovery is reopening.
    init(url: URL) throws {
        self.url = url
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        self.handle = try FileHandle(forWritingTo: url)
        let end = try self.handle.seekToEnd()

        // A power failure mid-write leaves a truncated final line. Appending straight onto it
        // would glue two records together and cost us the good one as well as the bad one, so
        // close the ragged line off first. The truncated remnant stays in the file as one
        // unparseable line, which the analyzer skips.
        if end > 0 {
            try? self.handle.seek(toOffset: end - 1)
            let last = try? self.handle.read(upToCount: 1)
            _ = try? self.handle.seekToEnd()
            if last != Data([0x0A]) {
                try? self.handle.write(contentsOf: Data([0x0A]))
            }
        }

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        // Deterministic key order keeps diffs and eyeballing sane.
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
    }

    /// Encodes and appends one record. Never throws to the caller — a write failure must not be
    /// allowed to tear down an in-progress recording. Failures are counted and surfaced in the UI.
    func write<T: Encodable & Sendable>(_ sample: T) {
        queue.async { [self] in
            guard var data = try? encoder.encode(sample) else {
                Self.failedWrites.withLock { $0 += 1 }
                return
            }
            data.append(0x0A) // newline
            do {
                try handle.write(contentsOf: data)
                sinceSync += 1
                if sinceSync >= syncEvery {
                    sinceSync = 0
                    fsync(handle.fileDescriptor)
                }
            } catch {
                Self.failedWrites.withLock { $0 += 1 }
            }
        }
    }

    /// Flushes and closes. Safe to call more than once.
    func close() {
        queue.sync { [self] in
            fsync(handle.fileDescriptor)
            do { try handle.close() } catch { /* already closed — nothing useful to do */ }
        }
    }

    /// Blocks until every queued write has hit the file descriptor. Used when the app is about to
    /// be suspended or terminated.
    func flush() {
        queue.sync { [self] in
            _ = fsync(handle.fileDescriptor)
        }
    }

    var fileSize: Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) .flatMap { $0 } ?? 0
    }

    /// Count of records we failed to persist. Should always be zero; if it isn't, the UI says so
    /// loudly rather than pretending the recording is clean.
    static let failedWrites = Mutex(0)
}

/// Minimal mutex wrapper so the failure counter can be touched from any isolation domain.
nonisolated final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }

    var current: Value { withLock { $0 } }
}
