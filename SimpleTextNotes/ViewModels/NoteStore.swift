import Foundation
import SwiftData

@Observable
@MainActor
class NoteStore {
    var notes: [Note] = []

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadNotes()
    }

    func addNote() -> Note {
        let note = Note()
        modelContext.insert(note)
        saveAndReload()
        return note
    }

    func deleteNote(_ note: Note) {
        modelContext.delete(note)
        saveAndReload()
    }

    func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notes[index])
        }
        saveAndReload()
    }

    func updateNote(_ note: Note) {
        saveAndReload()
    }

    func loadNotes() {
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        notes = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveAndReload() {
        try? modelContext.save()
        loadNotes()
    }
}
