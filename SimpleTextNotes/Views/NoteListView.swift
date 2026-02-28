import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNoteID: UUID?
    @State private var lastSyncDate: Date? = nil
    @State private var searchText: String = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List(selection: $selectedNoteID) {
            ForEach(filteredNotes) { note in
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
                let deletedIDs = offsets.map { filteredNotes[$0].id }
                if let selected = selectedNoteID, deletedIDs.contains(selected) {
                    selectedNoteID = nil
                }
                for index in offsets.sorted().reversed() {
                    modelContext.delete(filteredNotes[index])
                }
            }
        }
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search notes")
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
