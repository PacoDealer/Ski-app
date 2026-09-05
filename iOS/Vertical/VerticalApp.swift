import SwiftUI

@main
struct VerticalApp: App {
    @State private var recorder: TrackRecorder
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Runs before anything is on screen, and on a background relaunch there may never *be* a
        // screen — iOS can wake the app for a location event with the UI never appearing. So the
        // recovery check lives here rather than in `onAppear`: if the app died mid-day, recording
        // restarts the moment the process does.
        _recorder = State(initialValue: {
            let r = TrackRecorder()
            r.resumeIfInterrupted()
            return r
        }())
    }

    /// DEBUG-only: open straight onto one recording's detail screen, named by a launch argument.
    ///
    ///     xcrun simctl launch booted com.gamberg.vertical -screenshotSession 2026-09-01_portillo_s1
    ///
    /// **Why this exists.** A simulator has no GPS and no barometer, so the record screen can only
    /// ever show zeroes there — but `SessionDetailView` replays a *file*, so it renders a real ski
    /// day perfectly well in the simulator, which is the only place a screenshot can be taken
    /// without asking Martin to hold a phone. Getting to that screen by hand needs two taps, and
    /// the harness here has no way to tap: the location prompt sits on top of the first screen and
    /// the Simulator does not expose its buttons to accessibility. So the screen names itself.
    ///
    /// It also skips the location prompt entirely by never constructing the record screen, which
    /// is the thing that asks. Nothing in this path exists in a release build.
    static var screenshotSession: SessionFile? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshotSession"), i + 1 < args.count else {
            return nil
        }
        let dir = TrackRecorder.sessionsDirectory
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir,
                                                                includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "jsonl" }
            .map(SessionFile.init)
            .first { $0.displayName.contains(args[i + 1]) }
        #else
        return nil
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if let file = Self.screenshotSession {
                // See `screenshotSession`. Wrapped in its own stack so the detail screen gets a
                // navigation bar exactly as it does in the app.
                NavigationStack { SessionDetailView(file: file) }
                    .preferredColorScheme(.dark)
            } else {
                ContentView(recorder: recorder)
                    .preferredColorScheme(.dark)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Anything queued gets forced to disk the moment we stop being frontmost. The
            // recording itself keeps running in the background — that's the whole point.
            switch phase {
            case .background, .inactive: recorder.flush()
            default: break
            }
        }
    }
}
