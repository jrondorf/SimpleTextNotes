import SwiftUI
import SwiftData

@main
struct SimpleTextNotesApp: App {
    let modelContainer: ModelContainer
    @State private var noteStore: NoteStore

    init() {
        let schema = Schema([Note.self])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
            self._noteStore = State(initialValue: NoteStore(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: noteStore)
        }
        .modelContainer(modelContainer)
    }
}
