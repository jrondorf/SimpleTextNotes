import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var selectedNoteID: UUID?

    var body: some View {
        NavigationSplitView {
            NoteListView(selectedNoteID: $selectedNoteID)
        } detail: {
            if let noteID = selectedNoteID,
               let note = notes.first(where: { $0.id == noteID }) {
                NoteDetailView(note: note, selectedNoteID: $selectedNoteID)
                    .id(noteID)
            } else {
                ContentUnavailableView("No Note Selected", systemImage: "note.text", description: Text("Select a note from the list or create a new one."))
            }
        }
    }
}
