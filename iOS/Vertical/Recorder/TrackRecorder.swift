import Foundation
import CoreLocation
import CoreMotion
import UIKit

/// Drives the sensors and feeds `SampleWriter`. Deliberately does **no** analysis — no fusion, no
/// segmentation, no vertical math. Those are built later, against the files this produces.
///
/// The only numbers computed here are the ones shown live on screen so Martin can tell at a glance
/// that the thing is actually alive in his pocket. They are throwaway.
@Observable
@MainActor
final class TrackRecorder {

    // MARK: - Live state (display only)

    private(set) var isRecording = false
    private(set) var startedAt: Date?
    private(set) var locCount = 0
    private(set) var baroCount = 0
    private(set) var lastSpeed: Double = -1        // m/s, Doppler, negative = invalid
    private(set) var lastGPSAltitude: Double = 0   // m
    private(set) var lastRelativeAltitude: Double = 0 // m, barometric, relative to start
    private(set) var lastHorizontalAccuracy: Double = -1
    /// How many fixes carried a usable Doppler speed. Surfaced live because Doppler is the field
    /// the entire max-speed approach depends on, and it's absent indoors — this makes "is the GPS
    /// actually healthy?" answerable at a glance on the mountain instead of after a file pull.
    private(set) var dopplerValidCount = 0
    private(set) var markCount = 0
    private(set) var lastMarkLabel: String?
    private(set) var lastMarkAt: Date?
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined
    private(set) var altimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    /// True when the bundle can't legally record in the background, so the UI can say so plainly.
    private(set) var backgroundUpdatesUnavailable = false
    private(set) var lastError: String?

    /// Naive running descent, summed from barometric deltas. **This is not the real vertical
    /// metric** — summing every negative delta is precisely the bug that gives the whole category
    /// its 5–10% overestimate. It's here only as a liveness indicator.
    private(set) var roughDescent: Double = 0
    private var lastRelForDescent: Double?

    var failedWrites: Int { SampleWriter.failedWrites.current }
    var fileSize: Int { writer?.fileSize ?? 0 }
    var sessionURL: URL? { writer?.url }

    // MARK: - Private

    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private var writer: SampleWriter?
    private var proxy: LocationDelegateProxy?
    private var batteryTimer: Timer?

    init() {
        proxy = LocationDelegateProxy(owner: self)
        manager.delegate = proxy
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        // .fitness lets the OS apply pedestrian/vehicle heuristics we do not want on a piste.
        // .other keeps it dumb, which is what we need.
        manager.activityType = .other
        // Non-negotiable: iOS will otherwise decide a chairlift looks like "stationary" and stop
        // the updates without telling us. That is a recording silently dying — the exact failure
        // mode we're building this app to avoid.
        manager.pausesLocationUpdatesAutomatically = false
        authStatus = manager.authorizationStatus

        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    // MARK: - Authorization

    func requestAuthorization() {
        // Always is required so a phone that locks in a pocket keeps recording all day.
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestAlwaysAuthorization()
        }
    }

    // MARK: - Session control

    func start() {
        guard !isRecording else { return }

        let now = Date()
        let id = UUID().uuidString
        do {
            let url = try Self.newSessionURL(at: now, id: id)
            let w = try SampleWriter(url: url)
            writer = w

            let meta = MetaSample(
                startedAt: now,
                bootTimeRef: ProcessInfo.processInfo.systemUptime,
                sessionID: id,
                device: Self.deviceModel(),
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                formatVersion: SampleWriter.formatVersion
            )
            w.write(meta)
        } catch {
            lastError = "Couldn't open session file: \(error.localizedDescription)"
            return
        }

        startedAt = now
        locCount = 0
        baroCount = 0
        dopplerValidCount = 0
        markCount = 0
        lastMarkLabel = nil
        lastMarkAt = nil
        roughDescent = 0
        lastRelForDescent = nil
        lastError = nil
        isRecording = true

        enableBackgroundUpdatesIfPossible()
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.ingestBaro(relAlt: data.relativeAltitude.doubleValue,
                                pressure: data.pressure.doubleValue)
            }
        }

        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.ingestAbsoluteAltitude(data)
            }
        }

        note("session started; auth=\(manager.authorizationStatus.rawValue)")
        logBattery()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.logBattery() }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false

        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        altimeter.stopRelativeAltitudeUpdates()
        altimeter.stopAbsoluteAltitudeUpdates()
        batteryTimer?.invalidate()
        batteryTimer = nil

        logBattery()
        writer?.write(EndSample(dt: elapsed, locCount: locCount, baroCount: baroCount))
        writer?.close()
        writer = nil
        startedAt = nil
    }

    /// Tags the current moment. These hand-placed markers are the ground truth that run/lift
    /// segmentation gets validated against later — the most valuable thing in the file per byte.
    func mark(_ label: String) {
        guard isRecording else { return }
        writer?.write(MarkSample(dt: elapsed, label: label))
        markCount += 1
        lastMarkLabel = label
        lastMarkAt = Date()
    }

    func note(_ text: String) {
        guard isRecording else { return }
        writer?.write(NoteSample(dt: elapsed, text: text))
    }

    /// Force everything to disk. Called when the app is backgrounded or about to die.
    func flush() { writer?.flush() }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    // MARK: - Ingest

    fileprivate func ingest(_ locations: [CLLocation]) {
        guard isRecording, let startedAt else { return }
        for l in locations {
            let s = LocSample(
                dt: l.timestamp.timeIntervalSince(startedAt),
                ts: l.timestamp,
                lat: l.coordinate.latitude,
                lon: l.coordinate.longitude,
                alt: l.altitude,
                ellAlt: l.ellipsoidalAltitude,
                hAcc: l.horizontalAccuracy,
                vAcc: l.verticalAccuracy,
                speed: l.speed,
                speedAcc: l.speedAccuracy,
                course: l.course,
                courseAcc: l.courseAccuracy
            )
            writer?.write(s)
            locCount += 1
            if l.speed >= 0 && l.speedAccuracy >= 0 { dopplerValidCount += 1 }
            lastSpeed = l.speed
            lastGPSAltitude = l.altitude
            lastHorizontalAccuracy = l.horizontalAccuracy
        }
    }

    private func ingestBaro(relAlt: Double, pressure: Double) {
        guard isRecording else { return }
        writer?.write(BaroSample(dt: elapsed, relAlt: relAlt, pressure: pressure))
        baroCount += 1
        lastRelativeAltitude = relAlt

        if let prev = lastRelForDescent, relAlt < prev {
            roughDescent += (prev - relAlt)
        }
        lastRelForDescent = relAlt
    }

    private func ingestAbsoluteAltitude(_ data: CMAbsoluteAltitudeData) {
        guard isRecording else { return }
        writer?.write(AbsAltSample(dt: elapsed,
                                   altitude: data.altitude,
                                   accuracy: data.accuracy,
                                   precision: data.precision))
    }

    fileprivate func authChanged(_ status: CLAuthorizationStatus) {
        authStatus = status
        note("authorization changed to \(status.rawValue)")
        if isRecording { enableBackgroundUpdatesIfPossible() }
    }

    /// Turns on background updates, but only when it is actually legal to do so.
    ///
    /// `allowsBackgroundLocationUpdates = true` raises an Objective-C exception — an instant,
    /// uncatchable crash — if the bundle doesn't declare the `location` background mode. That
    /// bit us once already: `INFOPLIST_KEY_UIBackgroundModes` is silently ignored by Xcode's
    /// Info.plist generator, so the key vanished from the build with no warning and the app died
    /// the moment recording started.
    ///
    /// A misconfiguration must never be able to kill a recording, so we check the bundle
    /// ourselves and degrade to foreground-only with a visible warning instead.
    private func enableBackgroundUpdatesIfPossible() {
        let authorized = manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
        guard authorized else { return }

        guard Self.declaresLocationBackgroundMode else {
            backgroundUpdatesUnavailable = true
            note("UIBackgroundModes lacks 'location' — recording is foreground-only")
            return
        }
        backgroundUpdatesUnavailable = false
        manager.allowsBackgroundLocationUpdates = true
    }

    /// Whether `Info.plist` actually declares the `location` background mode.
    static let declaresLocationBackgroundMode: Bool = {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("location") ?? false
    }()

    fileprivate func failed(_ error: Error) {
        lastError = error.localizedDescription
        note("location error: \(error.localizedDescription)")
    }

    private func logBattery() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState.rawValue
        note("battery level=\(level) state=\(state) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
    }

    // MARK: - Files

    static var sessionsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func newSessionURL(at date: Date, id: String) throws -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        let name = "\(fmt.string(from: date))_\(id.prefix(8)).jsonl"
        return sessionsDirectory.appendingPathComponent(name)
    }

    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

/// CoreLocation's delegate methods carry no actor annotations, so a `@MainActor` type can't conform
/// cleanly under Swift 6. This nonisolated proxy takes the callbacks and hops them to the main
/// actor, which is where they already arrive anyway (the manager is created on main).
private final class LocationDelegateProxy: NSObject, CLLocationManagerDelegate {
    private weak var owner: TrackRecorder?

    init(owner: TrackRecorder) {
        self.owner = owner
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { owner?.ingest(locations) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated { owner?.authChanged(status) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { owner?.failed(error) }
    }
}
