import SwiftUI
import SwiftData
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
    /// The last AI-button request hit the daily Private Cloud Compute limit.
    @State private var pccQuotaLimitReached: Bool = false
    /// The limit was hit but the on-device model answered instead.
    @State private var showPCCQuotaNotice: Bool = false
    // Read so the PCC note and the AI button update when consent changes in Settings.
    @AppStorage(PrivateCloudComputeConsent.storageKey) private var pccConsent: PrivateCloudComputeConsent = .undecided
    @State private var timestampTask: Task<Void, Never>?
    /// Word and character counts for the footer; nil until the first count finishes.
    @State private var textCounts: NoteTextCounts?
    @State private var countTask: Task<Void, Never>?
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

    /// AI requests from this note go to Private Cloud Compute (consented and available).
    private var usesPrivateCloudCompute: Bool {
        pccConsent == .granted && SimpleTextNotesAI.isPrivateCloudComputeSupported
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

            Divider()

            // Word / character count footer
            HStack {
                if usesPrivateCloudCompute {
                    privateCloudComputeNote
                }
                Spacer()
                Text(String(format: String(localized: "word_count_format"),
                            textCounts?.words ?? 0, textCounts?.characters ?? 0))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
                    // Keep the footer's height while the first count runs, without flashing "0 words".
                    .opacity(textCounts == nil ? 0 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "untitled_note") : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: note.title)   { scheduleTimestampUpdate() }
        .onChange(of: note.content) {
            scheduleTimestampUpdate()
            scheduleCountUpdate(after: Self.countDebounceInterval)
        }
        .task { scheduleCountUpdate(after: nil) }
        .onDisappear {
            commitTimestampUpdate()
            countTask?.cancel()
            countTask = nil
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
                        .help(usesPrivateCloudCompute ? "ai_improve_pcc_help" : "ai_improve_help")
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
            if pccQuotaLimitReached && SimpleTextNotesAI.canShowQuotaLimitIncreaseOptions {
                Button("ai_pcc_quota_options_button") { SimpleTextNotesAI.showQuotaLimitIncreaseOptions() }
            }
            Button("ok_button", role: .cancel) { }
        } message: {
            if let msg = aiError { Text(msg) } else { Text("ai_generation_failed_message") }
        }
        .alert("ai_pcc_quota_title", isPresented: $showPCCQuotaNotice) {
            if SimpleTextNotesAI.canShowQuotaLimitIncreaseOptions {
                Button("ai_pcc_quota_options_button") { SimpleTextNotesAI.showQuotaLimitIncreaseOptions() }
            }
            Button("ok_button", role: .cancel) { }
        } message: {
            Text("ai_pcc_quota_fallback_message")
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

    // MARK: - Private Cloud Compute note

    /// Says where AI requests go, like the note next to HoroDrift's Analyze button.
    private var privateCloudComputeNote: some View {
        Label("ai_pcc_footer_label", systemImage: "lock.icloud")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .help("ai_pcc_privacy_message")
            .accessibilityHint(Text("ai_pcc_privacy_message"))
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

    // MARK: - Word and character counts

    private static let countDebounceInterval: Duration = .milliseconds(500)

    /// Recount once typing pauses. Counting walks the whole note, so it runs off the main
    /// actor and never inside `body`; a newer edit cancels the pending or running count.
    private func scheduleCountUpdate(after delay: Duration?) {
        countTask?.cancel()
        countTask = Task { @MainActor in
            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            let text = note.content
            guard let counts = await NoteTextCounts.count(text), !Task.isCancelled else { return }
            textCounts = counts
        }
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

        do {
            let truncated = String(content.prefix(Self.maxContentLengthForTitleGeneration))
            let generated = try await notesAI.respond(
                to: "Generate a very short title (maximum \(Self.maxTitleLength) characters) for this note. Reply with only the title text, no quotes, no punctuation at the end, no explanation:\n\n\(truncated)"
            )
            // Re-check after the async gap: note must still be active and untitled
            guard !generated.isEmpty, note.title.isEmpty, note.modelContext != nil else { return }
            note.title = String(generated.prefix(Self.maxTitleLength))
            note.updatedAt = Date()
        } catch {
            // Title generation failed silently; note keeps an empty title
        }
    }

    @MainActor
    private func generateContent() async {
        guard SimpleTextNotesAI.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let prompt = note.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Register undo before mutating content
            let originalContent = note.content
            undoManager?.registerUndo(withTarget: note) { note in
                note.content = originalContent
                note.updatedAt = Date()
            }
            undoManager?.setActionName(String(localized: "ai_button"))

            pccQuotaLimitReached = false
            let generated = try await notesAI.respond(
                to: prompt,
                instructions: "You are a helpful writing assistant. Improve, expand, or process the given note content.",
                onQuotaLimitReached: { pccQuotaLimitReached = true }
            )
            // Reaching here after the limit means the on-device model answered instead.
            showPCCQuotaNotice = pccQuotaLimitReached
            guard !generated.isEmpty else { return }
            note.content = "\(note.content)\n\n\(generated)"
            note.updatedAt = Date()
        } catch {
            aiError = notesAI.wrap(error).localizedDescription
        }
    }
}

// MARK: - NoteTextCounts

/// Word and character counts of a note, as shown in the editor footer.
private struct NoteTextCounts: Equatable, Sendable {
    let words: Int
    let characters: Int

    /// How many characters to count between cancellation checks.
    private static let cancellationCheckInterval = 16_384

    /// Counts in a single pass without allocating per word. A word is a run of characters
    /// that are not whitespace or newlines (`Character.isWhitespace` covers both).
    /// Returns nil if the calling task was cancelled part-way.
    ///
    /// `@concurrent` keeps it on the global executor, off the main actor, even if the target
    /// later turns on main-actor default isolation or `NonisolatedNonsendingByDefault`.
    @concurrent
    static func count(_ text: String) async -> NoteTextCounts? {
        var words = 0
        var characters = 0
        var isInWord = false
        for character in text {
            characters += 1
            if character.isWhitespace {
                isInWord = false
            } else if !isInWord {
                isInWord = true
                words += 1
            }
            if characters % cancellationCheckInterval == 0, Task.isCancelled {
                return nil
            }
        }
        return NoteTextCounts(words: words, characters: characters)
    }
}
