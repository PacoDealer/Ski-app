import Foundation
import CoreMotion

/// Logs device motion — accelerometer and gyroscope — alongside the GPS and barometer track.
///
/// **Strictly additive by construction.** This class owns its own `CMMotionManager` and its own
/// serial queue, holds the `SampleWriter` directly, and never touches `TrackRecorder`, the main
/// thread, or `LiveMetrics`. If every line of it failed, the location and barometer recording it
/// sits beside would be bit-for-bit unchanged. That is deliberate: it was added with about five
/// ski days left in the season, and the recorder is the one component that must not break.
///
/// **Why it exists at all** is written up on `ImuSample` — briefly, everything else in the file
/// arrives at ~1 Hz and a ski turn takes one to two seconds, so nothing recorded so far can
/// describe *how* a run was skied, only where it went. Whether a pocketed phone can measure turns
/// well is unknown and untested. The argument for capturing anyway is asymmetry, not confidence:
/// analysis can be redone forever, a day skied without the sensor cannot.
nonisolated final class MotionRecorder: @unchecked Sendable {

    /// 25 Hz. A ski turn lasts roughly 1–2 s, so this puts 25–50 samples inside one, which is
    /// ample for rhythm and airtime; the accelerometer's own noise floor makes more of it dubious
    /// value per byte. Raising it is a one-line change and the files stay readable, because every
    /// batch records the rate it was captured at.
    static let hz: Double = 25

    /// Live count of motion samples written, for the on-screen readout. R17: a sensor that can
    /// fail silently in a pocket gets a number on the main screen before it gets a feature, so a
    /// dead IMU is caught on the first chairlift rather than at the end of the day.
    static let sampleCount = Mutex(0)

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.gamberg.vertical.motion"
        q.maxConcurrentOperationCount = 1   // serial, so the buffer below needs no lock
        q.qualityOfService = .utility
        return q
    }()

    private var writer: SampleWriter?
    /// Added to a sample's uptime-based timestamp to get seconds since session start. Computed
    /// once at start so a resumed session lands on the same timeline as the samples it appends to.
    private var timeBase: TimeInterval = 0

    private var batchDt: TimeInterval?
    private var ax: [Double] = [], ay: [Double] = [], az: [Double] = []
    private var gx: [Double] = [], gy: [Double] = [], gz: [Double] = []
    private var vx: [Double] = [], vy: [Double] = [], vz: [Double] = []

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Begins logging. `elapsed` is where the session's clock already stands, which is zero for a
    /// fresh recording and the recovered offset for a resumed one.
    func start(writer: SampleWriter, elapsed: TimeInterval) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }

        self.writer = writer
        // Sample timestamps are measured against system uptime, the same clock `bootTimeRef` in
        // the session header uses. Pinning the offset here rather than stamping arrival times
        // means a sample delayed by a busy queue still records when it was *taken*.
        timeBase = elapsed - ProcessInfo.processInfo.systemUptime
        reserve()

        manager.deviceMotionUpdateInterval = 1.0 / Self.hz
        // `.xArbitraryZVertical` aligns Z with gravity and leaves the horizontal reference
        // arbitrary — it needs no magnetometer, which is the right trade beside a chairlift's
        // steel cable and a pocketful of phone.
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.append(data)
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        // The handler runs on `queue`; hop onto it so the final partial second is flushed after
        // any update already in flight, not racing it.
        queue.addOperation { [weak self] in
            self?.flush()
            self?.writer = nil
        }
        queue.waitUntilAllOperationsAreFinished()
    }

    /// Push whatever is buffered to disk without stopping. Called when the app is backgrounded or
    /// about to be killed, so a jetsam costs at most the current partial second.
    func flushPending() {
        queue.addOperation { [weak self] in self?.flush() }
    }

    // MARK: - Private

    /// Called on `queue`, serially, so the buffers need no further synchronisation.
    private func append(_ d: CMDeviceMotion) {
        if batchDt == nil { batchDt = timeBase + d.timestamp }

        // 3 decimals. Acceleration is in g and rotation in rad/s, so this resolves ~1 mg and
        // ~0.06°/s — well below the sensor's own noise, and it roughly halves the file.
        ax.append(r(d.userAcceleration.x)); ay.append(r(d.userAcceleration.y)); az.append(r(d.userAcceleration.z))
        gx.append(r(d.rotationRate.x));     gy.append(r(d.rotationRate.y));     gz.append(r(d.rotationRate.z))
        vx.append(r(d.gravity.x));          vy.append(r(d.gravity.y));          vz.append(r(d.gravity.z))

        if ax.count >= Int(Self.hz) { flush() }
    }

    private func flush() {
        guard let dt = batchDt, !ax.isEmpty, let writer else { return }
        writer.write(ImuSample(dt: dt, hz: Self.hz,
                               ax: ax, ay: ay, az: az,
                               gx: gx, gy: gy, gz: gz,
                               vx: vx, vy: vy, vz: vz))
        Self.sampleCount.withLock { $0 += ax.count }
        batchDt = nil
        ax.removeAll(keepingCapacity: true); ay.removeAll(keepingCapacity: true); az.removeAll(keepingCapacity: true)
        gx.removeAll(keepingCapacity: true); gy.removeAll(keepingCapacity: true); gz.removeAll(keepingCapacity: true)
        vx.removeAll(keepingCapacity: true); vy.removeAll(keepingCapacity: true); vz.removeAll(keepingCapacity: true)
        reserve()
    }

    private func reserve() {
        let n = Int(Self.hz)
        for buf in [\MotionRecorder.ax, \MotionRecorder.ay, \MotionRecorder.az,
                    \MotionRecorder.gx, \MotionRecorder.gy, \MotionRecorder.gz,
                    \MotionRecorder.vx, \MotionRecorder.vy, \MotionRecorder.vz] {
            self[keyPath: buf].reserveCapacity(n)
        }
    }

    private func r(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
}
