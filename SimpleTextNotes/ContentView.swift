import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNoteID: UUID?
    @State private var showSettings: Bool = false
    @State private var showTrash: Bool = false
    @State private var titleGenerationState = TitleGenerationState()

    var body: some View {
        NavigationSplitView {
            NoteListView(selectedNoteID: $selectedNoteID)
        } detail: {
            if let noteID = selectedNoteID,
               let note = notes.first(where: { $0.id == noteID }) {
                NoteDetailView(note: note, selectedNoteID: $selectedNoteID)
                    .id(noteID)
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
            ToolbarItem(placement: .navigation) {
                Button {
                    showTrash = true
                } label: {
                    Label("trash_button", systemImage: "trash")
                }
                .help("trash_button")
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
        .sheet(isPresented: $showTrash) {
            NavigationStack {
                TrashView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("done_button") { showTrash = false }
                        }
                    }
            }
        }
        .environment(titleGenerationState)
        .task {
            purgeOldTrashNotes()
        }
    }

    private func purgeOldTrashNotes() {
        let retentionInterval = TimeInterval(Note.trashRetentionDays) * 24 * 60 * 60
        let cutoff = Date(timeIntervalSinceNow: -retentionInterval)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.deletedAt != nil }
        )
        if let trashedNotes = try? modelContext.fetch(descriptor) {
            for note in trashedNotes {
                if let deletedAt = note.deletedAt, deletedAt < cutoff {
                    modelContext.delete(note)
                }
            }
        }
    }
}
