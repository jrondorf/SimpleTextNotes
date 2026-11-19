import SwiftUI

struct SettingsView: View {
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0
    @AppStorage(PrivateCloudComputeConsent.storageKey) private var pccConsent: PrivateCloudComputeConsent = .undecided

    private let isPrivateCloudComputeSupported = SimpleTextNotesAI.isPrivateCloudComputeSupported

    var body: some View {
        Form {
            Section("editor_font_section_title") {
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

            if isPrivateCloudComputeSupported {
                aiSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle("settings_navigation_title")
    }

    // MARK: - Apple Intelligence

    private var aiSection: some View {
        Section {
            Toggle("ai_pcc_toggle_label", isOn: Binding(
                get: { pccConsent == .granted },
                set: { pccConsent = $0 ? .granted : .denied }
            ))
        } header: {
            Text("ai_settings_section_title")
        } footer: {
            Text("ai_pcc_settings_message")
        }
    }
}
