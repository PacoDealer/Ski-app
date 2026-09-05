import Foundation
import Testing
@testable import Vertical

/// The line on the ground, and the two display-only transforms that make it drawable.
///
/// The thing these tests exist to protect is the boundary: `SessionTrack` may smooth and thin as
/// much as it likes for a map, and must never let either escape into a number the app reports.
/// S12b/S14b measured Slopes smoothing its top speed (+3.59%) and S5 caught Carve publishing a
/// smoothed GPS altitude as vertical — this app's whole argument is that it does neither, so a
/// display transform that leaked would cost more than the map is worth.
struct SessionTrackTests {

    // MARK: - Collection

    @Test("The track is opt-in — nothing else pays for it")
    func trackIsOptIn() throws {
        let plain = try SessionReplay.summarize(Fixtures.portilloS1)
        #expect(plain.track.isEmpty, "the default must not collect a whole day of coordinates")

        let withTrack = try SessionReplay.summarize(Fixtures.portilloS1, collectTrack: true)
        #expect(!withTrack.track.isEmpty)
        // Collecting the track must not change a single number the screen shows.
        #expect(withTrack.descentM == plain.descentM)
        #expect(withTrack.maxSpeedMS == plain.maxSpeedMS)
        #expect(withTrack.runs.count == plain.runs.count)
    }

    @Test("Every run has a drawable line inside its own window")
    func runsHavePoints() throws {
        let s = try SessionReplay.summarize(Fixtures.portilloS1, collectTrack: true)
        for (i, run) in s.runs.enumerated() {
            let pts = s.track.points(in: run)
            #expect(pts.count > 10, "run \(i + 1) has almost no track")
            // The slice must not leak outside the run, or the map draws the lift.
            #expect(pts.allSatisfy { $0.dt >= run.startTime && $0.dt <= run.endTime })
        }
    }

    // MARK: - Display transforms, and the line they must not cross

    @Test("Smoothing is a median, and never invents a speed")
    func displaySpeedsAreHonest() {
        // A clean 10 m/s cruise with one 40 m/s spike and one unknown fix in it.
        var pts: [SessionTrack.Point] = (0..<11).map {
            .init(dt: Double($0), lat: 0, lon: 0, speedMS: 10)
        }
        pts[5] = .init(dt: 5, lat: 0, lon: 0, speedMS: 40)
        pts[8] = .init(dt: 8, lat: 0, lon: 0, speedMS: -1)

        let out = SessionTrack.displaySpeeds(pts)
        #expect(out.count == pts.count)
        // The median rejects the spike outright — a mean would have carried 6 m/s of it into
        // five neighbouring samples and painted a fast streak that was never skied.
        #expect(out[5] == 10)
        #expect(out[3] == 10)
        // An unknown stays unknown. Filling it in from neighbours would turn "no Doppler here"
        // into a confident colour, which is the one thing the grey band exists to prevent.
        #expect(out[8] == -1)
        // And it must not reach past the ends of the array.
        #expect(out[0] == 10 && out[10] == 10)
    }

    @Test("Thinning keeps the shape and both ends, and drops the pile-ups")
    func thinningKeepsTheShape() {
        // 50 fixes scattered inside a 3 m circle — a skier standing at the top of a pitch — then
        // three that actually travel.
        var pts: [SessionTrack.Point] = (0..<50).map {
            .init(dt: Double($0),
                  lat: 33.0 + Double($0 % 3) * 0.00001,
                  lon: -70.0, speedMS: 0.2)
        }
        for i in 0..<3 {
            pts.append(.init(dt: Double(50 + i), lat: 33.0 + 0.001 * Double(i + 1),
                             lon: -70.0, speedMS: 15))
        }

        let out = SessionTrack.thinned(pts)
        #expect(out.count < 8, "the 50-fix pile-up should collapse, got \(out.count)")
        #expect(out.first?.dt == 0, "the run must still start where it started")
        #expect(out.last?.dt == 52, "and must still end where it ended")
        // The three real steps survive: thinning removes scatter, not travel.
        #expect(out.contains { $0.dt == 52 })
    }

    @Test("Thinning a real run leaves a line, not a handful of points")
    func thinningOnRealData() throws {
        let s = try SessionReplay.summarize(Fixtures.portilloS1, collectTrack: true)
        let run = try #require(s.runs.first)
        let raw = Array(s.track.points(in: run))
        let thin = SessionTrack.thinned(raw)
        #expect(thin.count < raw.count, "a 1 Hz run always contains fixes that did not move")
        #expect(thin.count > 50, "but the descent must still be a line, got \(thin.count)")
    }

    // MARK: - The range the ramp is stretched over

    @Test("The colour range is percentile-based, so one bad second cannot own it")
    func rangeIgnoresTheBurst() throws {
        // 2026-09-01 is the burst day: the file contains a multipath second the gate rejects, and
        // its ungated maximum is 5 km/h above the published one. A min/max colour range would let
        // a single fix flatten the whole ramp — the display-layer form of the defect R25 found in
        // `analyze.py`, where one 95 µs redelivery printed 341,659 km/h.
        let s = try SessionReplay.summarize(Fixtures.portilloS1, collectTrack: true)
        let all = s.runs.flatMap { Array(s.track.points(in: $0)) }
        let range = try #require(SessionTrack.speedRange(all))

        let gated = all.map(\.speedMS).filter { $0 >= 0 }
        let hardMax = try #require(gated.max())
        #expect(range.hi < hardMax, "the 95th percentile must sit under the single fastest fix")
        #expect(range.lo >= 0)
        #expect(range.hi > range.lo)
    }

    @Test("A run with no speed spread gets no range rather than an amplified one")
    func flatRunHasNoRange() {
        let pts: [SessionTrack.Point] = (0..<20).map {
            .init(dt: Double($0), lat: 0, lon: 0, speedMS: 10 + Double($0 % 2) * 0.1)
        }
        // 0.1 m/s of jitter is not a heatmap. Stretching the full ramp over it would paint a
        // dramatic-looking gradient onto a constant-speed traverse.
        #expect(SessionTrack.speedRange(pts) == nil)
    }
}
