import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isTrashed == false }) private var notes: [Note]
    @State private var selectedNote: Note?
    @State private var showSettings: Bool = false
    @State private var titleGenerationState = TitleGenerationState()
    @State private var notesAI = SimpleTextNotesAI()
    @State private var syncMonitor = CloudKitSyncMonitor()

    private static let appGroupID = "group.de.futural.simpletextnotes"
    private static let isoFormatter = ISO8601DateFormatter()

    var body: some View {
        NavigationSplitView {
            NoteListView(selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                NoteDetailView(note: note, selectedNote: $selectedNote)
                    .id(note.id)
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
        .environment(titleGenerationState)
        .environment(notesAI)
        .environment(syncMonitor)
        .task {
            purgeOldTrashNotes()
            importPendingSharedNotes()
            syncNotesList()
        }
        .onChange(of: notes) { _, _ in
            syncNotesList()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            importPendingSharedNotes()
        }
        #endif
    }

    private func purgeOldTrashNotes() {
        let retentionInterval = TimeInterval(Note.trashRetentionDays) * 24 * 60 * 60
        let cutoff = Date(timeIntervalSinceNow: -retentionInterval)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                note.isTrashed == true
            }
        )
        do {
            let trashed = try modelContext.fetch(descriptor)
            let expired = trashed.filter { ($0.deletedAt ?? Date.distantFuture) < cutoff }
            for note in expired {
                modelContext.delete(note)
            }
        } catch {
            print("SimpleTextNotes: failed to purge old trash notes — \(error)")
        }
    }

    /// Upper bound on one drain, so a write that never lands cannot spin the main actor.
    private static let maxSharedNotesPerDrain = 100

    private func importPendingSharedNotes() {
        // Consume one entry at a time: an entry leaves the shared inbox only once
        // its note exists, so a crash mid-import can never discard the whole batch.
        for _ in 0..<Self.maxSharedNotesPerDrain {
            guard let entry = Self.popPendingSharedNote() else { return }
            guard let content = entry["content"], !content.isEmpty else { continue }
            let action = entry["action"] ?? "new"
            if action == "append", let noteIdString = entry["noteId"], let uuid = UUID(uuidString: noteIdString) {
                let descriptor = FetchDescriptor<Note>(
                    predicate: #Predicate<Note> { $0.isTrashed == false }
                )
                if let allNotes = try? modelContext.fetch(descriptor),
                   let note = allNotes.first(where: { $0.id == uuid }) {
                    note.content = note.content.isEmpty ? content : note.content + "\n\n" + content
                    note.updatedAt = Date()
                } else {
                    insertSharedNote(content: content)
                }
            } else {
                insertSharedNote(content: content)
            }
        }
    }

    private func insertSharedNote(content: String) {
        let note = Note()
        note.content = content
        modelContext.insert(note)
        scheduleAutoTitle(for: note)
    }

    // MARK: - Shared inbox

    /// Sentinel file in the shared container used to serialize `pendingSharedNotes`
    /// access between the app and the share extension. Mirrored in `ShareViewController`.
    private static let sharedInboxLockURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: ContentView.appGroupID)?
        .appendingPathComponent("pendingSharedNotes.lock")

    /// Removes and returns the oldest entry written by the share extension, or `nil`
    /// when the inbox is empty. Coordinated so a concurrent share is never clobbered.
    private static func popPendingSharedNote() -> [String: String]? {
        var entry: [String: String]?
        withSharedInboxLock {
            let defaults = UserDefaults(suiteName: appGroupID)
            guard var pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]],
                  !pending.isEmpty else { return }
            entry = pending.removeFirst()
            if pending.isEmpty {
                defaults?.removeObject(forKey: "pendingSharedNotes")
            } else {
                defaults?.set(pending, forKey: "pendingSharedNotes")
            }
        }
        return entry
    }

    private static func withSharedInboxLock(_ body: @escaping () -> Void) {
        guard let url = sharedInboxLockURL else {
            body()
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        var didRun = false
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { _ in
            body()
            didRun = true
        }
        // Coordination itself failed — better an uncoordinated read than a stuck inbox.
        if !didRun { body() }
    }

    private func syncNotesList() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let list: [[String: String]] = notes.map { note in
            ["id": note.id.uuidString,
             "title": note.title,
             "updatedAt": Self.isoFormatter.string(from: note.updatedAt)]
        }
        defaults?.set(list, forKey: "notesList")
    }

    // MARK: - AI Title Generation (Share Extension)

    private static let maxTitleLength = 60
    private static let maxContentLengthForTitleGeneration = 1000

    private func scheduleAutoTitle(for note: Note) {
        guard SimpleTextNotesAI.isAvailable else { return }
        let noteID = note.id
        let task = Task {
            defer {
                Task { @MainActor in titleGenerationState.markDone(noteID) }
            }
            await generateAutoTitle(for: note)
        }
        titleGenerationState.startTask(task, for: noteID, showIndicator: false)
    }

    @MainActor
    private func generateAutoTitle(for note: Note) async {
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.title.isEmpty, !content.isEmpty else { return }
        guard SimpleTextNotesAI.isAvailable else { return }

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            do {
                let session = try notesAI.makeSession()
                let truncated = String(content.prefix(Self.maxContentLengthForTitleGeneration))
                let response = try await session.respond(
                    to: "Generate a very short title (maximum \(Self.maxTitleLength) characters) for this note. Reply with only the title text, no quotes, no punctuation at the end, no explanation:\n\n\(truncated)"
                )
                let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !generated.isEmpty, note.title.isEmpty, note.modelContext != nil else { return }
                note.title = String(generated.prefix(Self.maxTitleLength))
                note.updatedAt = Date()
            } catch {
                // Title generation failed silently; note keeps an empty title
            }
        }
#endif
    }
}
