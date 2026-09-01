//
// replay.swift — run the app's own `LiveMetrics` over a recorded session file.
//
//   Tools/replay.sh Data/fixtures/2026-09-01_portillo_s1.jsonl
//
// which is just:
//   swiftc -O -parse-as-library -o replay Tools/replay.swift \
//       iOS/Vertical/Recorder/LiveMetrics.swift
//
// **Why this exists.** `LiveMetrics` is the on-device port of the two rules `analyze.py` earned in
// S5. A port is a claim that two implementations agree, and a claim needs evidence (WORKFLOW R1) —
// especially here, where the Swift version is *streaming* and the Python version is *batch*, so
// they are not the same algorithm written twice, they are two algorithms that must produce the
// same answer. This runs the real, unmodified app source over the real fixtures so the two can be
// diffed without a phone, a mountain, or a rebuild.
//
// It also means a threshold can never be changed in one place only: change `analyze.py`, and this
// disagrees until `LiveMetrics.swift` is changed too.

import Foundation

func kmh(_ ms: Double) -> Double { ms * 3.6 }

@main
enum Replay {
static func main() {
for path in CommandLine.arguments.dropFirst() {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
        exit(1)
    }

    var m = LiveMetrics()
    var locs = 0, baros = 0, seams = 0

    for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = obj["t"] as? String else { continue }

        switch kind {
        case "loc":
            locs += 1
            m.ingestFix(speed: obj["speed"] as? Double ?? -1,
                        horizontalAccuracy: obj["hAcc"] as? Double ?? -1,
                        speedAccuracy: obj["speedAcc"] as? Double ?? -1,
                        at: obj["dt"] as? Double ?? 0)
        case "baro":
            baros += 1
            m.ingestAltitude(obj["relAlt"] as? Double ?? 0, at: obj["dt"] as? Double ?? 0)
        case "note":
            // The altimeter's baseline restarts at zero on a resume; the app calls
            // beginAltitudeSegment() at the same moment, so the replay must too.
            if let text = obj["text"] as? String, text.hasPrefix("resumed after interruption") {
                seams += 1
                m.beginAltitudeSegment()
            }
        default:
            break
        }
    }
    m.finish()

    print("=== \(URL(fileURLWithPath: path).lastPathComponent)")
    print(String(format: "  %d loc, %d baro, %d resume seam(s)", locs, baros, seams))
    print(String(format: "  max speed, gated      %6.1f km/h", kmh(m.maxSpeed)))
    print(String(format: "  max speed, ungated    %6.1f km/h", kmh(m.maxSpeedUngated)))
    print(String(format: "  runs                  %6d", m.runCount))
    print(String(format: "  descent, run-segmented%6.0f m", m.descentM))
    print(String(format: "  sub-threshold, unused %6.0f m", m.subThresholdDropM))
    for (i, r) in m.runs.enumerated() {
        print(String(format: "   %2d. %6.0f m  %5.1f min", i + 1, r.drop, r.duration / 60))
    }
}
}
}
