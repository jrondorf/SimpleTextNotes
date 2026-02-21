import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNoteID: UUID?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List(selection: $selectedNoteID) {
            ForEach(notes) { note in
                NavigationLink(value: note.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title.isEmpty ? "Untitled" : note.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(dateFormatter.string(from: note.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in
                let deletedIDs = offsets.map { notes[$0].id }
                if let selected = selectedNoteID, deletedIDs.contains(selected) {
                    selectedNoteID = nil
                }
                for index in offsets {
                    modelContext.delete(notes[index])
                }
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let note = Note()
                    modelContext.insert(note)
                    selectedNoteID = note.id
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
