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

// MARK: - Sort option

enum NoteSortOption: String {
    case updatedAt, createdAt, title
}

// MARK: - NoteListView

struct NoteListView: View {
    @Query(filter: #Predicate<Note> { $0.isTrashed == false }) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Environment(TitleGenerationState.self) private var titleGenerationState
    @Environment(CloudKitSyncMonitor.self) private var syncMonitor
    @Binding var selectedNote: Note?
    @State private var searchText: String = ""
    @State private var showTrash: Bool = false
    @AppStorage("noteSortOption") private var sortOptionRaw: String = NoteSortOption.updatedAt.rawValue

    private var sortOption: NoteSortOption {
        NoteSortOption(rawValue: sortOptionRaw) ?? .updatedAt
    }

    private var displayedNotes: [Note] {
        let filtered = searchText.isEmpty ? notes : notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            switch sortOption {
            case .updatedAt: return a.updatedAt > b.updatedAt
            case .createdAt: return a.createdAt > b.createdAt
            case .title:     return a.title.localizedCompare(b.title) == .orderedAscending
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(displayedNotes) { note in
                NavigationLink(value: note) {
                    HStack(alignment: .center, spacing: 8) {
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
                        if note.isPinned {
                            Spacer()
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        note.isPinned.toggle()
                    } label: {
                        Label(note.isPinned ? "unpin_note_button" : "pin_note_button",
                              systemImage: note.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.orange)
                }
            }
            .onDelete { offsets in
                let deleted = offsets.map { displayedNotes[$0] }
                if let selected = selectedNote, deleted.contains(where: { $0.id == selected.id }) {
                    selectedNote = nil
                }
                let now = Date()
                for note in deleted {
                    note.deletedAt = now
                    note.isTrashed = true
                }
            }
        }
        .onChange(of: notes) { _, updated in
            // Clear selection if the selected note was removed from active notes
            if let selected = selectedNote, !updated.contains(where: { $0.id == selected.id }) {
                selectedNote = nil
            }
        }
        .navigationTitle("notes_navigation_title")
        .searchable(text: $searchText, placement: .toolbar, prompt: "search_notes_prompt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let note = Note()
                    modelContext.insert(note)
                    selectedNote = note
                } label: {
                    Label("new_note_button", systemImage: "square.and.pencil")
                }
                .help("new_note_button")
                .keyboardShortcut("n", modifiers: .command)
            }

            ToolbarItem(placement: .primaryAction) {
                iCloudSyncIndicator
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("sort_button", selection: $sortOptionRaw) {
                        Text("sort_updated_at").tag(NoteSortOption.updatedAt.rawValue)
                        Text("sort_created_at").tag(NoteSortOption.createdAt.rawValue)
                        Text("sort_title").tag(NoteSortOption.title.rawValue)
                    }
                } label: {
                    Label("sort_button", systemImage: "arrow.up.arrow.down")
                }
                .help("sort_button")
            }

            #if canImport(UIKit)
            ToolbarItem(placement: .topBarLeading) {
                trashButton
            }
            #else
            ToolbarItem(placement: .navigation) {
                trashButton
            }
            #endif
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

    @ViewBuilder
    private var iCloudSyncIndicator: some View {
        switch syncMonitor.syncState {
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate, isActive: true)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("icloud_syncing_label"))
        case .synced:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("icloud_synced_label"))
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
                .accessibilityLabel(Text("icloud_error_label"))
        case .notSyncing:
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("icloud_label"))
        }
    }

    private var trashButton: some View {
        Button {
            showTrash = true
        } label: {
            Label("trash_button", systemImage: "trash")
        }
        .help("trash_button")
    }
}
