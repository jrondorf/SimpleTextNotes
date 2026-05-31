import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isTrashed == false }) private var notes: [Note]
    @State private var selectedNote: Note?
    @State private var showSettings: Bool = false
    @State private var titleGenerationState = TitleGenerationState()
    @State private var notesAI = SimpleTextNotesAI()
    @State private var syncMonitor = CloudKitSyncMonitor()

    private static let appGroupID = "group.de.futural.simpletextnotes"
    private static let isoFormatter = ISO8601DateFormatter()

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
            syncNotesList()
        }
        .onChange(of: notes) { _, _ in
            syncNotesList()
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
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard let pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]],
              !pending.isEmpty else { return }
        defaults?.removeObject(forKey: "pendingSharedNotes")
        for entry in pending {
            guard let content = entry["content"], !content.isEmpty else { continue }
            let action = entry["action"] ?? "new"
            if action == "append", let noteIdString = entry["noteId"], let uuid = UUID(uuidString: noteIdString) {
                let descriptor = FetchDescriptor<Note>(
                    predicate: #Predicate<Note> { $0.isTrashed == false }
                )
                if let allNotes = try? modelContext.fetch(descriptor),
                   let note = allNotes.first(where: { $0.id == uuid }) {
                    note.content = note.content.isEmpty ? content : note.content + "\n" + content
                    note.updatedAt = Date()
                } else {
                    let note = Note()
                    note.content = content
                    modelContext.insert(note)
                }
            } else {
                let note = Note()
                note.content = content
                modelContext.insert(note)
            }
        }
    }

    private func syncNotesList() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let list: [[String: String]] = notes.map { note in
            ["id": note.id.uuidString,
             "title": note.title,
             "updatedAt": Self.isoFormatter.string(from: note.updatedAt)]
        }
        defaults?.set(list, forKey: "notesList")
    }
}
