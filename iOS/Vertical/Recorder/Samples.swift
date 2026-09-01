import Foundation

/// Wire format for the raw sample log.
///
/// Everything is written as JSONL — one self-describing JSON object per line, tagged by `t`.
/// The point of this file is **fidelity, not convenience**: we log every field the OS gives us,
/// unprocessed, so the whole analysis pipeline can be rewritten later and replayed against real
/// snow without needing to be on a mountain again. Nothing here should ever do math.
nonisolated enum SampleKind: String, Codable {
    case meta       // session header, written once at start
    case loc        // CLLocation
    case baro       // CMAltimeter relative altitude (barometric)
    case abs        // CMAltimeter absolute altitude
    case imu        // batched device motion — accelerometer + gyroscope
    case mark       // user-pressed marker
    case note       // lifecycle event (background, resumed, authorization change, …)
    case end        // clean session close
}

/// One second of device motion, stored column-wise.
///
/// **Why this exists.** GPS and the barometer arrive at about 1 Hz, and a ski turn takes one to
/// two seconds — so every file recorded before 2026-09-01 can describe the path taken and nothing
/// at all about the act of skiing it. Turn rhythm, airtime, chatter and how hard a ski is loaded
/// all live above 1 Hz. Analysis can be rewritten forever; a day skied without this is gone, and
/// there were about five ski days left in the season when it was added. That asymmetry is the
/// whole argument — not a belief that any particular metric will work.
///
/// **Why column-wise, and why batched.** `SampleWriter` fsyncs every 20 records, which at 25 Hz
/// would mean an fsync roughly every 0.8 s. Batching a second at a time keeps the write and sync
/// rate at ~1 Hz, exactly as before, and storing parallel arrays instead of 25 little objects
/// drops the repeated JSON keys: about 1.6 kB per second, ~5.7 MB per hour.
///
/// **What is logged, and what isn't.** `userAcceleration` and `gravity` are kept separately —
/// that is the useful part for a phone loose in a pocket, because gravity gives the device's
/// orientation relative to vertical without needing to know how the phone is sitting. Attitude is
/// deliberately omitted: roll and pitch are recoverable from `gravity`, and yaw is not trustworthy
/// without a magnetometer reference we have no reason to trust on a chairlift.
nonisolated struct ImuSample: Codable {
    let t = SampleKind.imu
    /// Seconds since session start, for the **first** sample in the batch.
    let dt: TimeInterval
    /// Nominal sample rate, so a reader never has to guess the spacing.
    let hz: Double
    /// Motion the user contributes, gravity removed, in g. Device axes.
    let ax: [Double], ay: [Double], az: [Double]
    /// Rotation rate in rad/s. Device axes.
    let gx: [Double], gy: [Double], gz: [Double]
    /// The gravity vector in g, i.e. which way is down in device coordinates.
    let vx: [Double], vy: [Double], vz: [Double]

    enum CodingKeys: String, CodingKey {
        case t, dt, hz, ax, ay, az, gx, gy, gz, vx, vy, vz
    }
}

nonisolated struct MetaSample: Codable {
    let t = SampleKind.meta
    /// Wall clock at session start.
    let startedAt: Date
    /// Monotonic reference so we can detect clock changes across the session.
    let bootTimeRef: TimeInterval
    let sessionID: String
    let device: String
    let osVersion: String
    let appVersion: String
    let formatVersion: Int

    enum CodingKeys: String, CodingKey {
        case t, startedAt, bootTimeRef, sessionID, device, osVersion, appVersion, formatVersion
    }
}

/// A raw `CLLocation`, logged in full.
///
/// `speed` here is the receiver's own Doppler-derived speed — the single most important field in
/// this struct. Differentiating successive positions is what gives every other ski app its
/// ~10 mph max-speed error; we never do that, so we must capture this instead.
nonisolated struct LocSample: Codable {
    let t = SampleKind.loc
    /// Seconds since session start (from the sample's own timestamp, not arrival time).
    let dt: TimeInterval
    /// Absolute wall clock of the fix, for cross-referencing.
    let ts: Date
    let lat: Double
    let lon: Double
    /// Altitude above mean sea level, per CoreLocation's geoid model.
    let alt: Double
    /// Raw WGS-84 ellipsoidal altitude — no geoid correction applied. Kept because the geoid
    /// model itself is a source of systematic error we may want to back out later.
    let ellAlt: Double
    let hAcc: Double
    let vAcc: Double
    /// Doppler speed in m/s. Negative means invalid.
    let speed: Double
    /// Negative means the speed value above is not trustworthy. Gate on this, always.
    let speedAcc: Double
    let course: Double
    let courseAcc: Double

    enum CodingKeys: String, CodingKey {
        case t, dt, ts, lat, lon, alt, ellAlt, hAcc, vAcc, speed, speedAcc, course, courseAcc
    }
}

/// Barometric relative altitude. ~±0.3 m relative precision vs. GPS's ~±10 m — this is what
/// makes an honest vertical number possible. It drifts with weather, which is exactly why we log
/// raw pressure alongside it rather than a pre-fused value.
nonisolated struct BaroSample: Codable {
    let t = SampleKind.baro
    let dt: TimeInterval
    /// Metres relative to wherever the altimeter started. Not an absolute altitude.
    let relAlt: Double
    /// Ambient pressure in kPa.
    let pressure: Double

    enum CodingKeys: String, CodingKey { case t, dt, relAlt, pressure }
}

/// Absolute barometric altitude, where the device can provide it.
nonisolated struct AbsAltSample: Codable {
    let t = SampleKind.abs
    let dt: TimeInterval
    let altitude: Double
    let accuracy: Double
    let precision: Double

    enum CodingKeys: String, CodingKey { case t, dt, altitude, accuracy, precision }
}

/// A moment Martin tagged by hand. These are the ground truth that validates run/lift
/// segmentation later — worth far more than they look.
nonisolated struct MarkSample: Codable {
    let t = SampleKind.mark
    let dt: TimeInterval
    let label: String

    enum CodingKeys: String, CodingKey { case t, dt, label }
}

nonisolated struct NoteSample: Codable {
    let t = SampleKind.note
    let dt: TimeInterval
    let text: String

    enum CodingKeys: String, CodingKey { case t, dt, text }
}

nonisolated struct EndSample: Codable {
    let t = SampleKind.end
    let dt: TimeInterval
    let locCount: Int
    let baroCount: Int
    /// Individual motion samples, not batches. Zero on a device with no IMU, or if it never started.
    let imuCount: Int

    enum CodingKeys: String, CodingKey { case t, dt, locCount, baroCount, imuCount }
}
