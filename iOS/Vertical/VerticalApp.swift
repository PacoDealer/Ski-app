import SwiftUI

@main
struct VerticalApp: App {
    @State private var recorder = TrackRecorder()
    @Environment(\.scenePhase) private var scenePhase

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
