import SwiftUI
import SwiftData

struct TrashView: View {
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }, sort: \Note.updatedAt, order: .reverse) private var trashedNotes: [Note]
    @Environment(\.modelContext) private var modelContext

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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
                                .font(.headline)
                                .lineLimit(1)
                            if let deletedAt = note.deletedAt {
                                Text(Self.dateFormatter.string(from: deletedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            let daysRemaining = 30 - daysInTrash(for: note)
                            if daysRemaining > 0 {
                                Text(String(format: String(localized: "days_until_deletion_format"), daysRemaining))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
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
                                modelContext.delete(note)
                            } label: {
                                Label("delete_permanently_button", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("trash_navigation_title")
    }
}
