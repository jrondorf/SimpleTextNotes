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
