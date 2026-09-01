import SwiftUI

/// Lists recorded sessions and gets them off the phone.
///
/// Sharing matters more than it looks: it means a day's data can reach the Mac over AirDrop
/// without a cable, so analysis can start the same evening. The app also enables iTunes file
/// sharing and Files.app visibility, so there are three independent ways to recover a recording.
struct SessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [SessionFile] = []

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No recordings yet",
                                           systemImage: "figure.skiing.downhill",
                                           description: Text("Hit START to record a day."))
                } else {
                    List {
                        ForEach(sessions) { s in
                            row(s)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !sessions.isEmpty {
                        ShareLink(items: sessions.map(\.url)) {
                            Label("Share all", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func row(_ s: SessionFile) -> some View {
        HStack {
            // Tapping the row replays the file and shows what the day actually was. The share
            // button stays a separate target rather than becoming a swipe action or a menu item:
            // getting a recording off the phone is the one thing that must never take two guesses
            // in gloves at the bottom of a lift.
            NavigationLink(destination: SessionDetailView(file: s)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.displayName)
                        .font(.headline)
                    HStack(spacing: 10) {
                        Text(s.sizeText)
                        // A session with no `end` record was cut short — crash, force-quit, or
                        // dead battery. The file is still perfectly valid; we say so plainly
                        // instead of hiding it or asking a question about it.
                        if !s.closedCleanly {
                            Text("interrupted — data intact")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            ShareLink(item: s.url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func reload() {
        let dir = TrackRecorder.sessionsDirectory
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        sessions = urls
            .filter { $0.pathExtension == "jsonl" }
            .map(SessionFile.init)
            .sorted { $0.modified > $1.modified }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            try? FileManager.default.removeItem(at: sessions[i].url)
        }
        reload()
    }
}

struct SessionFile: Identifiable {
    let url: URL
    var id: String { url.lastPathComponent }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var size: Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) .flatMap { $0 } ?? 0
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var modified: Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) .flatMap { $0 } ?? .distantPast
    }

    /// Cheap check for a clean close: does the tail of the file contain an `end` record?
    /// Reading only the last 4 KB keeps this instant even for a full day's recording.
    var closedCleanly: Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let fileSize = size
        let offset = max(0, fileSize - 4096)
        try? handle.seek(toOffset: UInt64(offset))
        guard let data = try? handle.readToEnd(),
              let tail = String(data: data, encoding: .utf8) else { return false }
        return tail.contains("\"t\":\"end\"")
    }
}
