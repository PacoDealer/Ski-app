import SwiftUI

/// What a recorded day actually was — runs, vertical, top speed — on the phone, with no cable.
///
/// Before this screen the app was a capture rig: after a ski day it showed a filename and a byte
/// count, and every number that mattered needed a Mac and Python. It replays the file through the
/// same `LiveMetrics` that ran live, via `SessionReplay`, so nothing here is a second opinion.
///
/// It is also the half of the category that is paid: Slopes' free tier gives a **daily summary
/// only**, and per-run detail is Premium (`RESEARCH.md` §13.5).
///
/// This one is allowed to be less shouty than `ContentView` — it gets read sitting down, indoors,
/// not at speed in gloves. The **RECORDING QUALITY** section is the exception in spirit: it exists
/// so a bad day is visible as a bad day rather than as a plausible number, which is the whole
/// reason we keep raw files.
struct SessionDetailView: View {
    let file: SessionFile

    @State private var summary: SessionReplay.Summary?
    @State private var failed = false
    /// Which run the map is showing, or nil for the whole day.
    @State private var mapFocus: Int?
    /// For each run, the most similar other descent of the same day and how they overlap.
    ///
    /// Computed once on the background task rather than in `runRow`, which the list re-evaluates
    /// constantly: this is O(runs^2) overlaps at 32 samples each, and a 20-run day would pay it on
    /// every scroll frame.
    @State private var comparisons: [Int: (index: Int, overlap: RunComparison.Overlap)] = [:]
    /// DEBUG-only: `-screenshotRun 1` opens the map already focused on that run, because the
    /// screenshot harness has no way to work the picker. See `VerticalApp.screenshotSession`.
    private static var screenshotRun: Int? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshotRun"), i + 1 < args.count,
              let n = Int(args[i + 1]) else { return nil }
        return n - 1
        #else
        return nil
        #endif
    }

    var body: some View {
        Group {
            if let s = summary {
                content(s)
            } else if failed {
                ContentUnavailableView("Couldn't read this recording",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text("The file is still on disk and still valid — share it to the Mac and run Tools/analyze.py."))
            } else {
                // A 3 h day with motion is ~20 MB and tens of thousands of lines. Say so rather
                // than showing a bare spinner over a screen that looks stuck.
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Replaying \(file.sizeText)…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(file.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task(id: file.id, load)
    }

    /// Parsing happens off the main thread — this is CPU-bound over the whole file, and blocking
    /// the main actor here would freeze the list behind it for seconds on a full ski day.
    @Sendable private func load() async {
        let url = file.url
        let result = await Task.detached(priority: .userInitiated) {
            // The track is collected here and nowhere else — this is the one screen that draws it.
            try? SessionReplay.summarize(url, collectTrack: true)
        }.value
        if let r = result {
            comparisons = await Task.detached(priority: .userInitiated) {
                var out: [Int: (index: Int, overlap: RunComparison.Overlap)] = [:]
                for (i, run) in r.runs.enumerated() {
                    out[i] = RunComparison.closest(to: run, among: r.runs, in: r.track)
                }
                return out.compactMapValues { $0 }
            }.value
        }
        summary = result
        failed = result == nil
        if let r = Self.screenshotRun, let runs = result?.runs, runs.indices.contains(r) {
            mapFocus = r
        }
    }

    // MARK: - Content

    private func content(_ s: SessionReplay.Summary) -> some View {
        List {
            Section {
                headline(s)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            mapSection(s)

            Section("THE DAY") {
                row("Started", s.startedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                row("Duration", duration(s.duration))
                // Slopes prints this same pair on its day card, and in S7 it graded our detector
                // for free: our ski time read +33% high because runs counted standing at the top.
                row("Ski time", duration(s.skiTime))
                row("Descent distance",
                    String(format: "%.2f km", s.descentDistanceM / 1000))
                if !s.closedCleanly {
                    row("Closed", "interrupted — data intact", tint: .orange)
                }
                if s.resumeSeams > 0 {
                    row("Resumed", "\(s.resumeSeams)× after an interruption", tint: .orange)
                }
            }

            if s.runs.isEmpty {
                Section("RUNS") {
                    Text("No descent over \(Int(LiveMetrics.minRunDropM)) m in this recording.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("\(s.runs.count) RUNS") {
                    ForEach(Array(s.runs.enumerated()), id: \.offset) { i, r in
                        runRow(index: i + 1, run: r, all: s.runs)
                    }
                }
            }

            Section {
                row("Doppler speed", "\(s.dopplerValidCount) of \(s.locCount) fixes",
                    tint: s.dopplerRatio >= 0.8 ? .green : .orange)
                row("Horizontal accuracy",
                    s.hAccMedian >= 0 ? String(format: "median ±%.1f m", s.hAccMedian) : "—",
                    tint: s.hAccMedian >= 0 && s.hAccMedian <= 15 ? .green : .orange)
                // Stated, never hidden: the gate is a choice, and its cost belongs on screen.
                row("Rejected by speed gate", "\(s.speedGateRejected) fixes")
                if s.staleFixCount > 0 {
                    row("Pre-start cached fixes", "\(s.staleFixCount) excluded")
                }
                if s.metrics.subThresholdDropM > 0 {
                    row("Descent under threshold",
                        String(format: "%.0f m not counted", s.metrics.subThresholdDropM))
                }
                row("Barometer", "\(s.baroCount) readings")
                motionRow(s)
                if s.markCount > 0 { row("Hand tags", "\(s.markCount)") }
                row("File", "\(s.byteCount.formattedBytes) · v\(s.formatVersion)")
            } header: {
                Text("RECORDING QUALITY")
            } footer: {
                Text("These are the numbers that say whether the day above can be trusted. A recording is only as good as the fixes underneath it.")
            }

            if !s.marks.isEmpty {
                Section("HAND TAGS") {
                    ForEach(Array(s.marks.enumerated()), id: \.offset) { _, m in
                        HStack {
                            Text(m.label)
                            Spacer()
                            Text(clock(m.dt))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    /// The track, coloured by speed. Only appears when there is something to draw — a stationary
    /// recording or a file with no usable fixes gets no empty grey rectangle.
    @ViewBuilder
    private func mapSection(_ s: SessionReplay.Summary) -> some View {
        let drawn = mapFocus.map { s.runs.indices.contains($0) ? [s.runs[$0]] : s.runs } ?? s.runs
        let points = drawn.flatMap { Array(s.track.points(in: $0)) }
        if points.count >= 2 {
            Section {
                VStack(spacing: 8) {
                    TrackMapView(track: s.track, runs: s.runs, focus: mapFocus)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if let r = SessionTrack.speedRange(points) {
                        SpeedLegend(loKMH: r.lo * 3.6, hiKMH: r.hi * 3.6)
                    }
                    // Whole day or one run. A day at Portillo is 20 descents down the same few
                    // faces, so the day view is a picture of the resort and the per-run view is
                    // the one that shows a line.
                    Picker("Showing", selection: $mapFocus) {
                        Text("Whole day").tag(Int?.none)
                        ForEach(Array(s.runs.indices), id: \.self) { i in
                            Text("Run \(i + 1)").tag(Int?.some(i))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            } header: {
                Text("WHERE YOU SKIED")
            } footer: {
                Text("Colour is speed, light to dark. Grey means the fix carried no Doppler speed we trust — unknown, not slow. Lifts aren't drawn.")
            }
        }
    }

    private func headline(_ s: SessionReplay.Summary) -> some View {
        HStack(spacing: 10) {
            bigStat("VERTICAL", String(format: "%.0f", s.descentM), unit: "m")
            bigStat("TOP SPEED",
                    s.maxSpeedMS >= 0 ? String(format: "%.0f", s.maxSpeedMS * 3.6) : "—",
                    unit: "km/h",
                    // The ungated number is what an app without an accuracy gate would print.
                    // When the two diverge the day contains a multipath burst — which is exactly
                    // how Carve published a 4-second glitch as its top speed for 2026-09-01.
                    note: s.maxSpeedUngatedMS > s.maxSpeedMS
                        ? String(format: "ungated %.0f", s.maxSpeedUngatedMS * 3.6)
                        : "gate clean")
            bigStat("RUNS", "\(s.runs.count)")
        }
    }

    private func bigStat(_ label: String, _ value: String,
                         unit: String? = nil, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                if let unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Text(note ?? " ")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One run, with the five numbers Slopes itemises per run behind its paywall.
    ///
    /// Distance and the run's own top speed arrived in S14, and both are graded against Slopes'
    /// exports run by run (`Tools/grade.py`) rather than merely computed. The vertical rate stays
    /// because it is the one number here that needs no map to separate a pitch from a traverse —
    /// it is how run 2 of 2026-09-01 shows up as the 0.2 m/s crawl it was.
    private func runRow(index: Int, run: LiveMetrics.Run,
                        all: [LiveMetrics.Run]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .trailing)
                Text(String(format: "%.0f m", run.drop))
                    .font(.headline)
                Text("\(clock(run.startTime)) → \(clock(run.endTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(duration(run.duration))
                    .font(.body.monospacedDigit())
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: 34)
                stat(run.distanceM >= 1000
                     ? String(format: "%.2f km", run.distanceM / 1000)
                     : String(format: "%.0f m", run.distanceM), "distance")
                stat(run.topSpeedMS >= 0
                     ? String(format: "%.0f", run.topSpeedMS * 3.6) : "—", "top km/h")
                stat(String(format: "%.0f", run.averageSpeedMS * 3.6), "avg km/h")
                stat(String(format: "%.1f", run.verticalRateMS), "m/s vert")
            }
            if let c = comparisons[index - 1], all.indices.contains(c.index) {
                comparisonLine(otherIndex: c.index + 1, overlap: c.overlap)
            }
        }
        .padding(.vertical, 2)
    }

    /// The most similar other descent of this day, and how this one went by comparison.
    ///
    /// **It deliberately does not say "the same run".** Graded against Martin's 24 labels, no
    /// combination of separation and coverage separates same-piste pairs from different-piste ones
    /// — same-piste run 13–34 m apart while different-piste pairs start at 19 m (S15b, S18). What
    /// is honest is the measurement itself: how much of the mountain the two descents share, how
    /// far apart they were over it, and how the skiing differed. So the numbers are shown and the
    /// claim is not made. `≈` is doing real work in that sentence.
    private func comparisonLine(otherIndex: Int, overlap: RunComparison.Overlap) -> some View {
        // Takes no `Run`: every number here is scoped to the shared band and comes off `overlap`.
        // Passing the runs in would only make it possible to reach for a whole-run figure again.
        // Over the SHARED BAND, not over the two runs. See `RunComparison.Overlap.secondsA`.
        let delta = overlap.deltaSeconds
        return HStack(spacing: 0) {
            Color.clear.frame(width: 34)
            (Text("≈ run \(otherIndex)")
                .foregroundStyle(.tint)
             + Text("  ·  shares \(Int(overlap.sharedM)) m (\(Int(overlap.coverage * 100))%)")
             + Text("  ·  \(Int(overlap.separationM)) m apart")
             + Text(String(format: "  ·  %.0fs v %.0fs", overlap.secondsA, overlap.secondsB))
             + Text(abs(delta) < 1 ? "" : String(format: "  %@%.0fs", delta < 0 ? "−" : "+", abs(delta)))
                .foregroundStyle(delta < 0 ? .green : .orange))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// The IMU is the one sensor whose failure has no other symptom — the file just quietly lacks
    /// a day of motion. Coverage, not rate, is the number that catches it.
    @ViewBuilder
    private func motionRow(_ s: SessionReplay.Summary) -> some View {
        if s.imuCount > 0 {
            let ok = s.imuCoverage >= 0.95 && s.imuMaxGapS < 30
            row("Motion",
                String(format: "%.0f%% coverage · %.0f Hz", s.imuCoverage * 100, s.imuRateHz),
                tint: ok ? .green : .orange)
            if !ok {
                row("Longest motion gap", String(format: "%.0f s", s.imuMaxGapS), tint: .orange)
            }
        } else if s.formatVersion >= 2 {
            row("Motion", "none recorded", tint: .orange)
        }
    }

    private func row(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(tint ?? .secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Formatting

    /// Elapsed time from the session start, as `h:mm:ss` — the same clock the marks use, so a run
    /// can be lined up against a hand tag by eye.
    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func duration(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded())
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }
}

private extension Int {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
