import SwiftUI

struct SettingsView: View {
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0

    var body: some View {
        Form {
            Picker("Font Style", selection: $editorFontName) {
                Text("System").tag("system")
                Text("Monospaced").tag("monospaced")
                Text("Serif").tag("serif")
            }
            Picker("Font Size", selection: $editorFontSize) {
                Text("Small (14)").tag(14.0)
                Text("Medium (16)").tag(16.0)
                Text("Large (18)").tag(18.0)
                Text("Extra Large (20)").tag(20.0)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .navigationTitle("Editor Font")
    }
}
