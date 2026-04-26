import SwiftUI
import SwiftData
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
}
