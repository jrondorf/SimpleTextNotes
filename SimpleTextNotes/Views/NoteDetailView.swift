import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct NoteDetailView: View {
    @ObservedObject var store: NoteStore
    @Binding var selectedNoteID: UUID?
    let noteID: UUID

    @State private var title: String = ""
    @State private var content: String = ""

    private var note: Note? {
        store.notes.first { $0.id == noteID }
    }

    var body: some View {
        if note != nil {
            VStack(spacing: 0) {
                TextField("Title", text: $title)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .padding()
                    .onChange(of: title) {
                        saveChanges()
                    }

                Divider()

                TextEditor(text: $content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .onChange(of: content) {
                        saveChanges()
                    }
            }
            .navigationTitle(title.isEmpty ? "Untitled" : title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        if let note = note {
                            selectedNoteID = nil
                            store.deleteNote(note)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onAppear {
                loadNote()
            }
            .onChange(of: noteID) {
                loadNote()
            }
        } else {
            ContentUnavailableView("No Note Selected", systemImage: "note.text", description: Text("Select a note from the list or create a new one."))
        }
    }

    private func loadNote() {
        guard let note = note else { return }
        title = note.title
        content = note.content
    }

    private func saveChanges() {
        guard var note = note else { return }
        note.title = title
        note.content = content
        store.updateNote(note)
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let text = UIPasteboard.general.string {
            content = text
            saveChanges()
        }
        #elseif canImport(AppKit)
        if let text = NSPasteboard.general.string(forType: .string) {
            content = text
            saveChanges()
        }
        #endif
    }
}
