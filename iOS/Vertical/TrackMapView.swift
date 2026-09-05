import MapKit
import SwiftUI

/// The day on a map, with the track coloured by speed.
///
/// **Why this screen exists.** Speed heatmaps are on Slopes' Premium list (D7, `CLAUDE.md`), and
/// until now the app could tell you a run was 411 m at 47.6 km/h but not *where* any of it
/// happened. It needs no trail database and no ODbL attribution: the base map is Apple's and the
/// only data drawn on top is the user's own file.
///
/// **The colour is a design decision with a validated answer, not a taste.** Speed is a magnitude,
/// so the encoding is **sequential — one hue, light to dark** (`dataviz`). That deliberately
/// rejects the rainbow ramp this category defaults to: a rainbow has no perceptual order, so
/// "green vs yellow" carries no reading without a constant trip back to the legend, and it fails
/// for colour-blind users outright.
///
/// The ramp is the blue sequential scale, steps 250→700, **validated against pure white** rather
/// than against a chart surface, because the surface here is *snow*:
/// `validate_palette.js "#86b6ef,#5598e7,#2a78d6,#1c5cab,#0d366b" --ordinal --surface "#ffffff"`
/// passes all four checks, with the palest step still clearing the 2:1 floor at 2.11:1. The
/// obvious-looking tighter ramp (dropping the pale end) FAILED on adjacent lightness — the steps
/// bunched — which is exactly why the check is run rather than eyeballed.
///
/// Dark = fast is the right way round on snow: the fastest stretches are what the eye should find
/// first, and dark-on-white is the most legible pairing in direct alpine sunlight.
struct TrackMapView: UIViewRepresentable {

    let track: SessionTrack
    /// The runs to draw. Lifts and the walk to the car are deliberately not drawn — this is a
    /// picture of the skiing.
    let runs: [LiveMetrics.Run]
    /// Draw only this run, or all of them when nil.
    var focus: Int?

    // MARK: - The validated ramp

    /// Blue sequential, steps 250 / 350 / 450 / 550 / 700. Slow → fast.
    static let ramp: [UIColor] = [
        UIColor(red: 0.525, green: 0.714, blue: 0.937, alpha: 1),   // #86b6ef
        UIColor(red: 0.333, green: 0.596, blue: 0.906, alpha: 1),   // #5598e7
        UIColor(red: 0.165, green: 0.471, blue: 0.839, alpha: 1),   // #2a78d6
        UIColor(red: 0.110, green: 0.361, blue: 0.671, alpha: 1),   // #1c5cab
        UIColor(red: 0.051, green: 0.212, blue: 0.420, alpha: 1),   // #0d366b
    ]

    /// A fix whose Doppler speed did not pass the gate. Drawn, but in neutral ink and never as a
    /// ramp colour — "we do not know how fast this was" must not read as "this was slow".
    static let unknownColor = UIColor(white: 0.45, alpha: 0.9)

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .satelliteFlyover      // snow reads better than the vector map at a resort
        map.isRotateEnabled = false          // a glove on a map that spins is a lost map
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        let drawn = drawnRuns()
        let bands = context.coordinator.build(track: track, runs: drawn)
        guard !bands.isEmpty else { return }
        // The casing goes down first so every coloured band sits on top of it.
        map.addOverlays(bands, level: .aboveRoads)
        if let rect = context.coordinator.boundingRect, !rect.isNull {
            map.setVisibleMapRect(rect,
                                  edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                                  animated: false)
        }
    }

    private func drawnRuns() -> [LiveMetrics.Run] {
        guard let focus, runs.indices.contains(focus) else { return runs }
        return [runs[focus]]
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    /// Marks the casing overlay. Not a band index, so the renderer can tell them apart.
    static let casingTitle = "casing"

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var casingTitle: String { TrackMapView.casingTitle }
        /// Set by `build`, so the caller can frame exactly what was drawn.
        private(set) var boundingRect: MKMapRect?
        /// The speed range the ramp was stretched over, for the legend.
        private(set) var range: (lo: Double, hi: Double)?

        /// One `MKMultiPolyline` per band — five overlays for a whole day, not one per segment.
        /// A 7 h day is ~23,000 fixes; adding an overlay each would be tens of thousands of
        /// renderers and a map that will not pan.
        func build(track: SessionTrack, runs: [LiveMetrics.Run]) -> [MKMultiPolyline] {
            var rect = MKMapRect.null
            let all = runs.flatMap { Array(track.points(in: $0)) }
            guard all.count >= 2 else { boundingRect = nil; return [] }

            let span = SessionTrack.speedRange(all)
            range = span

            // Group CONSECUTIVE points that fall in the same band into one polyline each, rather
            // than emitting a two-point polyline per pair. The per-pair version drew correctly and
            // looked wrong: with round caps, every 1 s segment paints a disc at both ends, so a
            // track renders as a string of blobs instead of a line. Contiguous stretches also cut
            // the polyline count by an order of magnitude.
            var byBand: [[ [CLLocationCoordinate2D] ]] = Array(repeating: [], count: ramp.count + 1)
            for run in runs {
                // Thinned by distance, then coloured off the smoothed speed. Both are display
                // concerns and neither touches a reported number — see `SessionTrack`.
                let pts = SessionTrack.thinned(Array(track.points(in: run)))
                guard pts.count >= 2 else { continue }
                let display = SessionTrack.displaySpeeds(pts)
                var current: [CLLocationCoordinate2D] = []
                var currentBand = -1

                func flush() {
                    if current.count >= 2, currentBand >= 0 { byBand[currentBand].append(current) }
                    current = []
                }

                for i in 0..<(pts.count - 1) {
                    let a = pts[i], b = pts[i + 1]
                    let coordA = CLLocationCoordinate2D(latitude: a.lat, longitude: a.lon)
                    let coordB = CLLocationCoordinate2D(latitude: b.lat, longitude: b.lon)
                    rect = rect.union(MKMapRect(coordinate: coordA).union(MKMapRect(coordinate: coordB)))

                    // A gap in the fixes is a gap in the line — never connect across one, or the
                    // map draws a straight line through a mountain the skier went around.
                    guard b.dt - a.dt <= 12 else { flush(); currentBand = -1; continue }

                    let bnd = band(for: display[i], in: span)
                    if bnd != currentBand {
                        // Carry the shared point into the next stretch so the colours meet with no
                        // gap between them.
                        let joint = current.last
                        flush()
                        currentBand = bnd
                        if let joint { current = [joint] }
                    }
                    if current.isEmpty { current = [coordA] }
                    current.append(coordB)
                }
                flush()
            }
            boundingRect = rect.isNull ? nil : rect

            var overlays = byBand.enumerated().compactMap { index, segments -> MKMultiPolyline? in
                guard !segments.isEmpty else { return nil }
                let multi = MKMultiPolyline(segments.map {
                    MKPolyline(coordinates: $0, count: $0.count)
                })
                multi.title = String(index)          // the band, read back by the renderer
                return multi
            }

            // The casing: one white line under everything, slightly wider.
            //
            // **This is what makes the colour validation true rather than aspirational.** The ramp
            // was checked against white on the assumption that a ski map is snow — and the first
            // screenshot disproved it: Apple's Portillo imagery is *summer* terrain whose mean
            // colour samples at #605b4f, a mid-dark brown. A mid-tone base is the worst case for a
            // sequential ramp, because the dark end disappears into it. Rather than re-step the
            // ramp for one resort's imagery — which would break at the next one, and in winter —
            // the line is given its own surface. Standard cartographic casing, and now the ramp
            // genuinely sits on white wherever it is drawn.
            if !overlays.isEmpty {
                let all = overlays.flatMap { $0.polylines }
                let casing = MKMultiPolyline(all)
                casing.title = casingTitle
                overlays.insert(casing, at: 0)
            }
            return overlays
        }

        /// Band 0…4 are the ramp; the last band is "speed unknown".
        private func band(for speed: Double, in span: (lo: Double, hi: Double)?) -> Int {
            guard speed >= 0 else { return ramp.count }
            guard let span else { return ramp.count - 1 }   // constant-speed run: one flat colour
            let t = (speed - span.lo) / max(span.hi - span.lo, 0.001)
            return min(ramp.count - 1, max(0, Int(t * Double(ramp.count))))
        }

        private var ramp: [UIColor] { TrackMapView.ramp }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let multi = overlay as? MKMultiPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKMultiPolylineRenderer(multiPolyline: multi)
            r.lineCap = .round
            r.lineJoin = .round
            if multi.title == casingTitle {
                r.strokeColor = UIColor.white.withAlphaComponent(0.9)
                r.lineWidth = 4.5
            } else {
                let index = Int(multi.title ?? "") ?? ramp.count
                r.strokeColor = index < ramp.count ? ramp[index] : TrackMapView.unknownColor
                // 2.5 pt, not 4. At whole-day zoom a Portillo run is ~2 km across a ~340 pt card,
                // so every point of stroke is ~6 m on the ground: a 4 pt line is 24 m wide and the
                // track reads as a worm whatever is done to the geometry underneath it.
                r.lineWidth = 2.5
            }
            return r
        }
    }
}

private extension MKMapRect {
    init(coordinate: CLLocationCoordinate2D) {
        let p = MKMapPoint(coordinate)
        self.init(x: p.x, y: p.y, width: 0, height: 0)
    }
}

/// The legend. A sequential ramp needs one — the colours mean nothing without their two ends, and
/// `dataviz` treats a missing legend as identity-by-colour-alone.
struct SpeedLegend: View {
    let loKMH: Double
    let hiKMH: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(TrackMapView.ramp.enumerated()), id: \.offset) { _, c in
                    Rectangle().fill(Color(uiColor: c))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            HStack {
                Text("\(Int(loKMH.rounded())) km/h")
                Spacer()
                Text("\(Int(hiKMH.rounded())) km/h")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }
}
