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

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder)
                .preferredColorScheme(.dark)
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
