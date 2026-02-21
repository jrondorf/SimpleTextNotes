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

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title)
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .padding()

            Divider()

            TextEditor(text: $note.content)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .navigationTitle(note.title.isEmpty ? "Untitled" : note.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showPasteConfirmation = true
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }

                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    selectedNoteID = nil
                    modelContext.delete(note)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Paste from Clipboard", isPresented: $showPasteConfirmation) {
            Button("Paste", role: .destructive) {
                pasteFromClipboard()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace the current note content with the clipboard text.")
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
