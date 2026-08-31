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

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            stat("SPEED", speedText, recorder.lastSpeed >= 0 ? .white : .orange)
            stat("GPS ALT", String(format: "%.0f m", recorder.lastGPSAltitude), .white)
            stat("BARO Δ", String(format: "%+.1f m", recorder.lastRelativeAltitude), .white)
            stat("ROUGH DESC", String(format: "%.0f m", recorder.roughDescent), .cyan)
            stat("GPS FIXES", "\(recorder.locCount)", .white)
            stat("BARO FIXES", "\(recorder.baroCount)", .white)
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
            Text("TAG A MOMENT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
