import SwiftUI
import SwiftData

@main
struct SimpleTextNotesApp: App {
    private let modelContainer: ModelContainer?
    private let initializationError: String?

    init() {
        let schema = Schema([Note.self])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.de.futural.simpletextnotes.v2"))
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.initializationError = nil
        } catch {
            self.modelContainer = nil
            self.initializationError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
            } else {
                DatabaseErrorView(message: initializationError ?? String(localized: "database_error_unknown_message"))
            }
        }
        .commands {
            NoteCommands()
        }
    }
}

// MARK: - Menu commands

/// Creates a note in one scene's window. `ContentView` publishes it with
/// `focusedSceneValue`, so a menu command acts on the key window only.
private struct NewNoteActionKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    var newNoteAction: (@MainActor () -> Void)? {
        get { self[NewNoteActionKey.self] }
        set { self[NewNoteActionKey.self] = newValue }
    }
}

/// `WindowGroup` puts "New Window" (⌘N) in the File menu on Mac Catalyst and iPadOS, and
/// the menu bar claims ⌘N before any view's `.keyboardShortcut` sees it. Replace that item
/// with "New Note" so ⌘N creates a note in the key window instead of opening a window.
private struct NoteCommands: Commands {
    @FocusedValue(\.newNoteAction) private var newNoteAction

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("new_note_button") {
                newNoteAction?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newNoteAction == nil)
        }
    }
}

private struct DatabaseErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("database_error_title")
                .font(.title2.bold())
            Text("database_error_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
