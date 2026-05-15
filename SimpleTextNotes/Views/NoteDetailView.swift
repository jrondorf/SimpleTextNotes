import SwiftUI
import SwiftData
import FoundationModels
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct NoteDetailView: View {
    @Bindable var note: Note
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var modelContext
    @State private var showPasteConfirmation: Bool = false
    @State private var titleGenerationTask: Task<Void, Never>?
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0

    private var editorFont: Font {
        switch editorFontName {
        case "monospaced": return .system(size: editorFontSize, design: .monospaced)
        case "serif": return .system(size: editorFontSize, design: .serif)
        default: return .system(size: editorFontSize)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("note_title_placeholder", text: $note.title)
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .padding()

            Divider()

            TextEditor(text: $note.content)
                .font(editorFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: note.title) { note.updatedAt = Date() }
        .onChange(of: note.content) { note.updatedAt = Date() }
        .onDisappear {
            guard note.title.isEmpty else { return }
            titleGenerationTask?.cancel()
            titleGenerationTask = Task { await generateTitle() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Label("copy_button", systemImage: "doc.on.doc")
                }
                .help("copy_button")

                Button {
                    showPasteConfirmation = true
                } label: {
                    Label("paste_button", systemImage: "doc.on.clipboard")
                }
                .help("paste_button")

                Button(role: .destructive) {
                    selectedNoteID = nil
                    modelContext.delete(note)
                } label: {
                    Label("delete_button", systemImage: "trash")
                }
                .help("delete_button")
            }
        }
        .alert("paste_from_clipboard_alert_title", isPresented: $showPasteConfirmation) {
            Button("paste_alert_action", role: .destructive) {
                pasteFromClipboard()
            }
            Button("cancel_button", role: .cancel) { }
        } message: {
            Text("paste_clipboard_message")
        }
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = note.content
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.content, forType: .string)
        #endif
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let text = UIPasteboard.general.string {
            note.content = text
        }
        #elseif canImport(AppKit)
        if let text = NSPasteboard.general.string(forType: .string) {
            note.content = text
        }
        #endif
    }

    private static let maxTitleLength = 60
    private static let maxContentLengthForTitleGeneration = 1000

    @MainActor
    private func generateTitle() async {
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.title.isEmpty, !content.isEmpty else { return }

        guard case .available = SystemLanguageModel.default.availability else { return }

        do {
            let session = LanguageModelSession()
            let truncated = String(content.prefix(Self.maxContentLengthForTitleGeneration))
            let response = try await session.respond(
                to: "Generate a very short title (maximum \(Self.maxTitleLength) characters) for this note. Reply with only the title text, no quotes, no punctuation at the end, no explanation:\n\n\(truncated)"
            )
            let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Re-check after the async call in case a concurrent task already set a title
            guard !generated.isEmpty, note.title.isEmpty else { return }
            note.title = String(generated.prefix(Self.maxTitleLength))
            note.updatedAt = Date()
        } catch {
            // Title generation failed silently; the note keeps an empty title
        }
    }
}
