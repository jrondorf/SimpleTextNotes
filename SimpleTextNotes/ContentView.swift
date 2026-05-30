import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    @State private var showSettings: Bool = false
    @State private var titleGenerationState = TitleGenerationState()
    @State private var notesAI = SimpleTextNotesAI()
    @State private var syncMonitor = CloudKitSyncMonitor()

    var body: some View {
        NavigationSplitView {
            NoteListView(selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                NoteDetailView(note: note, selectedNote: $selectedNote)
                    .id(note.id)
            } else {
                ContentUnavailableView("no_note_selected_title", systemImage: "note.text", description: Text("no_note_selected_description"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showSettings = true
                } label: {
                    Label("settings_button", systemImage: "gearshape")
                }
                .help("settings_button")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("done_button") { showSettings = false }
                        }
                    }
            }
        }
        .environment(titleGenerationState)
        .environment(notesAI)
        .environment(syncMonitor)
        .task {
            purgeOldTrashNotes()
            importPendingSharedNotes()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            importPendingSharedNotes()
        }
        #endif
    }

    private func purgeOldTrashNotes() {
        let retentionInterval = TimeInterval(Note.trashRetentionDays) * 24 * 60 * 60
        let cutoff = Date(timeIntervalSinceNow: -retentionInterval)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                note.isTrashed == true
            }
        )
        do {
            let trashed = try modelContext.fetch(descriptor)
            let expired = trashed.filter { ($0.deletedAt ?? Date.distantFuture) < cutoff }
            for note in expired {
                modelContext.delete(note)
            }
        } catch {
            print("SimpleTextNotes: failed to purge old trash notes — \(error)")
        }
    }

    private func importPendingSharedNotes() {
        let defaults = UserDefaults(suiteName: "group.de.futural.simpletextnotes")
        guard let pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]],
              !pending.isEmpty else { return }
        defaults?.removeObject(forKey: "pendingSharedNotes")
        for entry in pending {
            guard let content = entry["content"], !content.isEmpty else { continue }
            let note = Note()
            note.content = content
            modelContext.insert(note)
        }
    }
}
