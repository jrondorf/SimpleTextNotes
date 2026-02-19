import SwiftUI

struct ContentView: View {
    var store: NoteStore
    @State private var selectedNoteID: UUID?

    var body: some View {
        NavigationSplitView {
            NoteListView(store: store, selectedNoteID: $selectedNoteID)
        } detail: {
            if let noteID = selectedNoteID {
                NoteDetailView(store: store, selectedNoteID: $selectedNoteID, noteID: noteID)
                    .id(noteID)
            } else {
                ContentUnavailableView("No Note Selected", systemImage: "note.text", description: Text("Select a note from the list or create a new one."))
            }
        }
    }
}
