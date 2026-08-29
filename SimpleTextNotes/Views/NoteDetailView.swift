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
    @Binding var selectedNote: Note?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(TitleGenerationState.self) private var titleGenerationState
    @Environment(SimpleTextNotesAI.self) private var notesAI
    @State private var showPasteConfirmation: Bool = false
    @State private var showAINoContent: Bool = false
    @State private var isGenerating: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var aiError: String?
    @State private var timestampTask: Task<Void, Never>?
    @State private var hasPendingTimestampUpdate: Bool = false
    @AppStorage("editorFontName") private var editorFontName: String = "system"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 16.0

    // @ScaledMetric props so each base size scales with the system Dynamic Type setting
    @ScaledMetric(relativeTo: .body) private var scaledSmall: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var scaledMedium: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var scaledLarge: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var scaledExtraLarge: CGFloat = 20

    private var effectiveFontSize: CGFloat {
        switch editorFontSize {
        case 14.0: return scaledSmall
        case 18.0: return scaledLarge
        case 20.0: return scaledExtraLarge
        default:   return scaledMedium
        }
    }

    private var editorFont: Font {
        switch editorFontName {
        case "monospaced": return .system(size: effectiveFontSize, design: .monospaced)
        case "serif":      return .system(size: effectiveFontSize, design: .serif)
        default:           return .system(size: effectiveFontSize)
        }
    }

    private var wordCount: Int {
        note.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var characterCount: Int { note.content.count }

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

            Divider()

            // Word / character count footer
            HStack {
                Spacer()
                Text(String(format: String(localized: "word_count_format"), wordCount, characterCount))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: note.title)   { scheduleTimestampUpdate() }
        .onChange(of: note.content) { scheduleTimestampUpdate() }
        .onDisappear {
            commitTimestampUpdate()
            guard note.title.isEmpty else { return }
            let noteID = note.id
            let isAvailable = SimpleTextNotesAI.isAvailable
            let task = Task {
                defer {
                    Task { @MainActor in titleGenerationState.markDone(noteID) }
                }
                await generateTitle()
            }
            titleGenerationState.startTask(task, for: noteID, showIndicator: isAvailable)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Pin / Unpin
                Button {
                    note.isPinned.toggle()
                } label: {
                    Label(note.isPinned ? "unpin_note_button" : "pin_note_button",
                          systemImage: note.isPinned ? "pin.slash.fill" : "pin")
                }
                .help(note.isPinned ? "unpin_note_button" : "pin_note_button")
                .keyboardShortcut("p", modifiers: [.command, .shift])

                // Share
                ShareLink(item: shareText) {
                    Label("share_button", systemImage: "square.and.arrow.up")
                }
                .help("share_button")
                .keyboardShortcut("s", modifiers: [.command, .shift])

                // AI improve
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
                        .help("ai_improve_help")
                    }
                }

                // Copy
                Button {
                    copyToClipboard()
                } label: {
                    Label("copy_button", systemImage: "doc.on.doc")
                }
                .help("copy_button")
                .keyboardShortcut("c", modifiers: [.command, .shift])

                // Paste
                Button {
                    showPasteConfirmation = true
                } label: {
                    Label("paste_button", systemImage: "doc.on.clipboard")
                }
                .help("paste_button")
                .keyboardShortcut("v", modifiers: [.command, .shift])

                // Delete
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("delete_button", systemImage: "trash")
                }
                .help("delete_button")
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
        .alert("ai_no_content_title", isPresented: $showAINoContent) {
            Button("ok_button", role: .cancel) { }
        } message: {
            Text("ai_no_content_message")
        }
        .alert("ai_generation_failed_title", isPresented: Binding(
            get: { aiError != nil },
            set: { if !$0 { aiError = nil } }
        )) {
            Button("ok_button", role: .cancel) { }
        } message: {
            if let msg = aiError { Text(msg) } else { Text("ai_generation_failed_message") }
        }
        .alert("delete_note_alert_title", isPresented: $showDeleteConfirmation) {
            Button("move_to_trash_button", role: .destructive) {
                selectedNote = nil
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

    // MARK: - Modification timestamp

    private static let timestampDebounceInterval: Duration = .seconds(1)

    /// Coalesce the `updatedAt` write. Stamping it on every keystroke re-sorts the
    /// sidebar while the user types and pushes a CloudKit change per character.
    private func scheduleTimestampUpdate() {
        hasPendingTimestampUpdate = true
        timestampTask?.cancel()
        timestampTask = Task { @MainActor in
            try? await Task.sleep(for: Self.timestampDebounceInterval)
            guard !Task.isCancelled else { return }
            commitTimestampUpdate()
        }
    }

    /// Write any coalesced edit through immediately (also called when the editor closes).
    private func commitTimestampUpdate() {
        timestampTask?.cancel()
        timestampTask = nil
        guard hasPendingTimestampUpdate else { return }
        hasPendingTimestampUpdate = false
        guard note.modelContext != nil else { return }
        note.updatedAt = Date()
    }

    // MARK: - Clipboard

    private var shareText: String {
        if note.title.isEmpty { return note.content }
        if note.content.isEmpty { return note.title }
        return "\(note.title)\n\n\(note.content)"
    }

    private func copyToClipboard() {
        let text = shareText
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func pasteFromClipboard() {
        let clipboard: String?
        #if canImport(UIKit)
        clipboard = UIPasteboard.general.string
        #elseif canImport(AppKit)
        clipboard = NSPasteboard.general.string(forType: .string)
        #endif
        guard let text = clipboard else { return }

        // Register undo so Cmd+Z restores the original content
        let originalContent = note.content
        undoManager?.registerUndo(withTarget: note) { note in
            note.content = originalContent
            note.updatedAt = Date()
        }
        undoManager?.setActionName(String(localized: "paste_button"))

        note.content = note.content.isEmpty ? text : note.content + "\n\n" + text
        note.updatedAt = Date()
    }

    // MARK: - AI

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
                // Re-check after the async gap: note must still be active and untitled
                guard !generated.isEmpty, note.title.isEmpty, note.modelContext != nil else { return }
                note.title = String(generated.prefix(Self.maxTitleLength))
                note.updatedAt = Date()
            } catch {
                // Title generation failed silently; note keeps an empty title
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

                // Register undo before mutating content
                let originalContent = note.content
                undoManager?.registerUndo(withTarget: note) { note in
                    note.content = originalContent
                    note.updatedAt = Date()
                }
                undoManager?.setActionName(String(localized: "ai_button"))

                let response = try await session.respond(to: prompt)
                let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !generated.isEmpty else { return }
                note.content = "\(note.content)\n\n\(generated)"
                note.updatedAt = Date()
            } catch {
                aiError = notesAI.wrap(error).localizedDescription
            }
        }
#endif
    }
}
