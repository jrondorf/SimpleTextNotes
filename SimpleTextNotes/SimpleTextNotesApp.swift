import SwiftUI
import SwiftData

@main
struct SimpleTextNotesApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Note.self])
        //let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.de.futural.simpletextnotes.v2"))

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
