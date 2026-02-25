import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNoteID: UUID?
    @State private var lastSyncDate: Date? = nil

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
        .refreshable {
            await refreshNotes()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let note = Note()
                    modelContext.insert(note)
                    selectedNoteID = note.id
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New Note")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    @MainActor private func refreshNotes() async {
        try? modelContext.save()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        lastSyncDate = Date()
    }
}
