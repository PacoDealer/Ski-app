//
// replay.swift — run the app's own session replay over a recorded session file.
//
//   Tools/replay.sh Data/fixtures/2026-09-01_portillo_s1.jsonl
//
// which is just:
//   swiftc -O -parse-as-library -o replay Tools/replay.swift \
//       iOS/Vertical/Recorder/LiveMetrics.swift iOS/Vertical/Recorder/SessionReplay.swift
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
//
// **S9: this file no longer parses anything itself.** The parse loop moved into
// `SessionReplay.swift`, which the app's session detail screen uses to replay a saved day on the
// phone. So the harness now checks the *whole* path the phone takes — including what counts as a
// resume seam — rather than a lookalike of it (R12a).

import Foundation

func kmh(_ ms: Double) -> Double { ms * 3.6 }

@main
enum Replay {
static func main() {
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let s = try? SessionReplay.summarize(url) else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
        exit(1)
    }

    print("=== \(url.lastPathComponent)")
    print(String(format: "  %d loc, %d baro, %d resume seam(s)",
                 s.locCount, s.baroCount, s.resumeSeams))
    print(String(format: "  duration              %6.1f min%@",
                 s.duration / 60, s.closedCleanly ? "" : "  (interrupted — data intact)"))
    print(String(format: "  max speed, gated      %6.1f km/h", kmh(s.maxSpeedMS)))
    print(String(format: "  max speed, ungated    %6.1f km/h", kmh(s.maxSpeedUngatedMS)))
    print(String(format: "  runs                  %6d", s.runs.count))
    print(String(format: "  descent, run-segmented%6.0f m", s.descentM))
    print(String(format: "  descent distance      %6.2f km",
                 s.runs.reduce(0) { $0 + $1.distanceM } / 1000))
    print(String(format: "  sub-threshold, unused %6.0f m", s.metrics.subThresholdDropM))
    print(String(format: "  ski time              %6.1f min", s.skiTime / 60))
    print(String(format: "  doppler valid         %6d/%d", s.dopplerValidCount, s.locCount))
    print(String(format: "  hAcc median           %6.1f m", s.hAccMedian))
    print(String(format: "  speed-gate rejected   %6d fix(es)", s.speedGateRejected))
    if s.imuCount > 0 {
        print(String(format: "  imu  %d samples, %.1f Hz, %.0f%% coverage, max gap %.1f s",
                     s.imuCount, s.imuRateHz, s.imuCoverage * 100, s.imuMaxGapS))
    }
    for (i, r) in s.runs.enumerated() {
        let top = r.topSpeedMS >= 0 ? String(format: "%5.1f", r.topSpeedMS * 3.6) : "    -"
        print(String(format: "   %2d. %6.0f m %6.0f m %5.1f min  top %@ km/h",
                     i + 1, r.drop, r.distanceM, r.duration / 60, top))
    }
}
}
}
