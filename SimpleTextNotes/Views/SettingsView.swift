import SwiftUI

struct SettingsView: View {
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0

    var body: some View {
        Form {
            Picker("font_style_picker", selection: $editorFontName) {
                Text("system_font_option").tag("system")
                Text("monospaced_font_option").tag("monospaced")
                Text("serif_font_option").tag("serif")
            }
            Picker("font_size_picker", selection: $editorFontSize) {
                Text("font_size_small").tag(14.0)
                Text("font_size_medium").tag(16.0)
                Text("font_size_large").tag(18.0)
                Text("font_size_extra_large").tag(20.0)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .navigationTitle("editor_font_navigation_title")
    }
}
