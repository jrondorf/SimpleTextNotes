import SwiftUI
import SwiftData

private struct GeneratingTitleView: View {
    private static let animationInterval: TimeInterval = 0.5

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.animationInterval)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / Self.animationInterval) % 3
            Text(String(repeating: ".", count: phase + 1))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

struct NoteListView: View {
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Environment(TitleGenerationState.self) private var titleGenerationState
    @Binding var selectedNoteID: UUID?
    @State private var searchText: String = ""
    @State private var showTrash: Bool = false

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private static let dateFormatter: DateFormatter = {
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
                        if note.title.isEmpty && titleGenerationState.isGenerating(note.id) {
                            GeneratingTitleView()
                        } else {
                            Text(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text(Self.dateFormatter.string(from: note.updatedAt))
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
                let now = Date()
                for index in offsets.sorted().reversed() {
                    filteredNotes[index].deletedAt = now
                }
            }
        }
        .navigationTitle("notes_navigation_title")
        .searchable(text: $searchText, placement: .toolbar, prompt: "search_notes_prompt")
        .refreshable {
            try? modelContext.save()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let note = Note()
                    modelContext.insert(note)
                    selectedNoteID = note.id
                } label: {
                    Label("new_note_button", systemImage: "square.and.pencil")
                }
                .help("new_note_button")
                .keyboardShortcut("n", modifiers: .command)
            }
            #if canImport(UIKit)
            ToolbarItem(placement: .topBarLeading) {
            #else
            ToolbarItem(placement: .navigation) {
            #endif
                Button {
                    showTrash = true
                } label: {
                    Label("trash_button", systemImage: "trash")
                }
                .help("trash_button")
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
    }
}
