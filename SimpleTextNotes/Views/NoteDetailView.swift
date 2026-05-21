import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct NoteDetailView: View {
    @Bindable var note: Note
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var modelContext
    @Environment(TitleGenerationState.self) private var titleGenerationState
    @State private var showPasteConfirmation: Bool = false
    @State private var titleGenerationTask: Task<Void, Never>?
    @State private var showAINoContent: Bool = false
    @State private var isGenerating: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0

    private let notesAI = SimpleTextNotesAI()

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
            let noteID = note.id
            titleGenerationTask = Task {
                let isAvailable = SimpleTextNotesAI.isAvailable
                if isAvailable { titleGenerationState.markGenerating(noteID) }
                defer { if isAvailable { titleGenerationState.markDone(noteID) } }
                await generateTitle()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if SimpleTextNotesAI.isAvailable {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button {
                            let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
                            if content.isEmpty {
                                showAINoContent = true
                            } else {
                                Task { await generateContent() }
                            }
                        } label: {
                            Label("ai_button", systemImage: "sparkles")
                        }
                        .help("ai_button")
                    }
                }

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
                    showDeleteConfirmation = true
                } label: {
                    Label("delete_button", systemImage: "trash")
                }
                .help("delete_button")
            }
        }
        .alert("ai_no_content_title", isPresented: $showAINoContent) {
            Button("ok_button", role: .cancel) { }
        } message: {
            Text("ai_no_content_message")
        }
        .alert("delete_note_alert_title", isPresented: $showDeleteConfirmation) {
            Button("move_to_trash_button", role: .destructive) {
                selectedNoteID = nil
                note.deletedAt = Date()
                note.isTrashed = true
            }
            Button("cancel_button", role: .cancel) { }
        } message: {
            Text("delete_note_alert_message")
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
                // Re-check after the async call in case a concurrent task already set a title
                guard !generated.isEmpty, note.title.isEmpty else { return }
                note.title = String(generated.prefix(Self.maxTitleLength))
                note.updatedAt = Date()
            } catch {
                // Title generation failed silently; the note keeps an empty title
            }
        }
#endif
    }

    @MainActor
    private func generateContent() async {
        guard SimpleTextNotesAI.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            do {
                let session = try notesAI.makeSession(instructions: "You are a helpful writing assistant. Improve, expand, or process the given note content.")
                let prompt = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
                let response = try await session.respond(to: prompt)
                let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !generated.isEmpty else { return }
                note.content = "\(note.content)\n\n\(generated)"
                note.updatedAt = Date()
            } catch {
                // Content generation failed silently
            }
        }
#endif
    }
}
