import SwiftUI
import CoreLocation

/// Deliberately ugly and deliberately huge.
///
/// This screen gets used outdoors, in glare, at speed, wearing gloves, possibly at -10°C. Every
/// target is oversized, every number is high-contrast, and the recording state is unmistakable
/// from arm's length. Pretty comes later — after there's real data to be pretty about.
struct ContentView: View {
    @Bindable var recorder: TrackRecorder
    @State private var showSessions = false
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusBanner
                    warnings
                    elapsedDisplay
                    headline
                    statsGrid
                    if recorder.isRecording { markButtons }
                    primaryButton
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Vertical")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sessions") { showSessions = true }
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showSessions) { SessionsView() }
            .onReceive(tick) { now = $0 }
            .onAppear { recorder.requestAuthorization() }
        }
    }

    // MARK: - Pieces

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(recorder.isRecording ? .red : .gray)
                .frame(width: 18, height: 18)
                .opacity(recorder.isRecording && Int(now.timeIntervalSince1970) % 2 == 0 ? 0.35 : 1)
            Text(recorder.isRecording ? "RECORDING" : "IDLE")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(recorder.isRecording ? .red : .secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var warnings: some View {
        VStack(spacing: 8) {
            // Good news rather than a warning, but it belongs in the same place: if the phone died
            // and came back, Martin should be able to see at a glance that nothing was lost — and
            // that he does *not* need to press START again.
            if let resumed = recorder.resumedAfterInterruption {
                Label("Recording resumed automatically — the app stopped for \(Int(resumed.gap / 60)) min and picked the same session back up. Nothing to do.",
                      systemImage: "arrow.clockwise.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
            // Without Always authorization the recording dies the moment the phone locks in a
            // pocket — which is where it will spend the entire day.
            if recorder.authStatus != .authorizedAlways {
                warning("Location is not set to “Always”. Recording will stop when the phone locks. Fix in Settings → Vertical → Location.")
            }
            if recorder.backgroundUpdatesUnavailable {
                warning("This build can't record in the background — it will stop when the phone locks. Don't ski with it; tell Claude.")
            }
            if !recorder.altimeterAvailable {
                warning("Barometric altimeter unavailable — altitude will be GPS-only and much worse.")
            }
            if recorder.failedWrites > 0 {
                warning("\(recorder.failedWrites) samples failed to write to disk.")
            }
            if let err = recorder.lastError {
                warning(err)
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.yellow, in: RoundedRectangle(cornerRadius: 12))
    }

    private var elapsedDisplay: some View {
        Text(formatDuration(recorder.isRecording ? recorder.elapsed : 0))
            .font(.system(size: 64, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
    }

    /// The three numbers a competitor's screen shows, computed our way.
    ///
    /// These exist so the app can be read **against Slopes and Carve on the mountain**, without a
    /// file pull — which is how the whole S5/S6 comparison was done, and how assumption A18 gets
    /// settled. Each one carries the naive alternative underneath in small type, because the gap
    /// between the two lines is the entire product thesis, and on 2026-09-01 it was live on this
    /// screen without anyone being able to see it.
    private var headline: some View {
        let m = recorder.metrics
        return HStack(spacing: 10) {
            headlineStat("VERTICAL",
                         String(format: "%.0f m", m.provisionalDescentM),
                         naive: String(format: "naive %.0f m", recorder.roughDescent))
            headlineStat("TOP SPEED",
                         m.maxSpeed >= 0 ? String(format: "%.0f", m.maxSpeed * 3.6) : "—",
                         unit: m.maxSpeed >= 0 ? "km/h" : nil,
                         // Ungated is what an app without an accuracy gate would print. When these
                         // differ, the difference is a bad second, and it is worth looking at that
                         // evening — this is the only warning we get on the mountain.
                         naive: m.maxSpeedUngated > m.maxSpeed
                             ? String(format: "ungated %.0f", m.maxSpeedUngated * 3.6) : "gate clean")
            headlineStat("RUNS", "\(m.runCount)",
                         naive: m.subThresholdDropM > 0
                             ? String(format: "+%.0f m sub", m.subThresholdDropM) : "—")
        }
    }

    private func headlineStat(_ label: String, _ value: String,
                              unit: String? = nil, naive: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Text(naive)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            stat("SPEED", speedText, recorder.lastSpeed >= 0 ? .white : .orange)
            stat("GPS ALT", String(format: "%.0f m", recorder.lastGPSAltitude), .white)
            stat("BARO Δ", String(format: "%+.1f m", recorder.lastRelativeAltitude), .white)
            stat("ROUGH DESC", String(format: "%.0f m", recorder.roughDescent), .cyan)
            stat("GPS FIXES", "\(recorder.locCount)", .white)
            stat("BARO FIXES", "\(recorder.baroCount)", .white)
            stat("DOPPLER", "\(recorder.dopplerValidCount)/\(recorder.locCount)", dopplerColor)
            stat("TAGS", "\(recorder.markCount)", .indigo)
            stat("H.ACC", recorder.lastHorizontalAccuracy >= 0
                 ? String(format: "±%.0f m", recorder.lastHorizontalAccuracy) : "—",
                 accuracyColor)
            stat("FILE", ByteCountFormatter.string(fromByteCount: Int64(recorder.fileSize),
                                                   countStyle: .file), .white)
        }
    }

    private var speedText: String {
        guard recorder.lastSpeed >= 0 else { return "—" }
        return String(format: "%.0f km/h", recorder.lastSpeed * 3.6)
    }

    /// Green once most fixes carry usable Doppler speed. Red means the receiver isn't giving us
    /// the one field max speed depends on — worth knowing before a whole day is recorded.
    private var dopplerColor: Color {
        guard recorder.locCount > 5 else { return .secondary }
        let ratio = Double(recorder.dopplerValidCount) / Double(recorder.locCount)
        if ratio >= 0.8 { return .green }
        if ratio >= 0.4 { return .yellow }
        return .orange
    }

    private var accuracyColor: Color {
        let a = recorder.lastHorizontalAccuracy
        if a < 0 { return .orange }
        if a <= 10 { return .green }
        if a <= 30 { return .yellow }
        return .orange
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Hand-placed ground truth. Every one of these makes the offline segmentation work
    /// dramatically easier to validate, so they're front and centre rather than buried.
    private var markButtons: some View {
        VStack(spacing: 10) {
            // Confirmation that a tap actually registered. Without it, the smoke test showed
            // three "Top" tags in three seconds — pressing again because nothing acknowledged
            // the first press. In gloves, on a lift, that guessing is worse.
            if let label = recorder.lastMarkLabel, let at = recorder.lastMarkAt,
               now.timeIntervalSince(at) < 4 {
                Label("Tagged “\(label)”", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            } else {
                Text("TAG A MOMENT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            HStack(spacing: 10) {
                markButton("Top", "arrow.up.to.line")
                markButton("Bottom", "arrow.down.to.line")
            }
            HStack(spacing: 10) {
                markButton("Lift on", "tram.fill")
                markButton("Lift off", "figure.skiing.downhill")
            }
        }
    }

    private func markButton(_ label: String, _ icon: String) -> some View {
        Button {
            recorder.mark(label)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } label: {
            Label(label, systemImage: icon)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
    }

    private var primaryButton: some View {
        Button {
            if recorder.isRecording { recorder.stop() } else { recorder.start() }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            Text(recorder.isRecording ? "STOP" : "START")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 100)
        }
        .buttonStyle(.borderedProminent)
        .tint(recorder.isRecording ? .red : .green)
        .padding(.top, 8)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
