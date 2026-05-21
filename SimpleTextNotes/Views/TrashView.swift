import SwiftUI
import SwiftData

// MARK: - Read-only view for a trashed note

private struct TrashedNoteDetailView: View {
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top)
                }
                Text(note.content.isEmpty ? String(localized: "untitled_note") : note.content)
                    .font(.body)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - TrashView

struct TrashView: View {
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }, sort: \Note.updatedAt, order: .reverse) private var trashedNotes: [Note]
    @Environment(\.modelContext) private var modelContext
    @State private var showEmptyTrashConfirmation: Bool = false
    @State private var noteToDelete: Note?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func daysInTrash(for note: Note) -> Int {
        guard let deletedAt = note.deletedAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
    }

    var body: some View {
        Group {
            if trashedNotes.isEmpty {
                ContentUnavailableView(
                    "empty_trash_title",
                    systemImage: "trash",
                    description: Text("empty_trash_description")
                )
            } else {
                List {
                    ForEach(trashedNotes) { note in
                        NavigationLink(destination: TrashedNoteDetailView(note: note)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                if let deletedAt = note.deletedAt {
                                    Text(Self.dateFormatter.string(from: deletedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                let daysRemaining = Note.trashRetentionDays - daysInTrash(for: note)
                                if daysRemaining > 0 {
                                    Text(String(format: String(localized: "days_until_deletion_format"), daysRemaining))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("overdue_deletion_label")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                note.deletedAt = nil
                            } label: {
                                Label("restore_note_button", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                noteToDelete = note
                            } label: {
                                Label("delete_permanently_button", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("trash_navigation_title")
        .toolbar {
            if !trashedNotes.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showEmptyTrashConfirmation = true
                    } label: {
                        Label("empty_trash_button", systemImage: "trash.slash")
                    }
                    .help("empty_trash_button")
                }
            }
        }
        .confirmationDialog(
            "empty_trash_confirm_title",
            isPresented: $showEmptyTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("empty_trash_confirm_action", role: .destructive) {
                for note in trashedNotes {
                    modelContext.delete(note)
                }
            }
            Button("cancel_button", role: .cancel) { }
        } message: {
            Text("empty_trash_confirm_message")
        }
        .alert(
            "delete_permanently_confirm_title",
            isPresented: Binding(
                get: { noteToDelete != nil },
                set: { if !$0 { noteToDelete = nil } }
            )
        ) {
            Button("delete_permanently_confirm_action", role: .destructive) {
                if let note = noteToDelete {
                    modelContext.delete(note)
                }
                noteToDelete = nil
            }
            Button("cancel_button", role: .cancel) { noteToDelete = nil }
        } message: {
            Text("delete_permanently_confirm_message")
        }
    }
}
