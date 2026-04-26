import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var selectedNoteID: UUID?
    @State private var showSettings: Bool = false

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
    }
}
