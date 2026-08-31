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
    case mark       // user-pressed marker
    case note       // lifecycle event (background, resumed, authorization change, …)
    case end        // clean session close
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

    enum CodingKeys: String, CodingKey { case t, dt, locCount, baroCount }
}
