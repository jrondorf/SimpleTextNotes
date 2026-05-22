import SwiftUI
import SwiftData
import CoreData
import Observation

// MARK: - CloudSyncMonitor

/// Observes NSPersistentStoreRemoteChange notifications to surface a brief syncing indicator.
@Observable
final class CloudSyncMonitor {
    var isSyncing: Bool = false

    func startObserving() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSyncing = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.isSyncing = false
            }
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    @State private var showSettings: Bool = false
    @State private var titleGenerationState = TitleGenerationState()
    @State private var notesAI = SimpleTextNotesAI()
    @State private var syncMonitor = CloudSyncMonitor()

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
            syncMonitor.startObserving()
        }
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
}
