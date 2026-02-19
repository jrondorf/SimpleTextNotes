import Foundation

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let savePath: URL

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        savePath = documentsDirectory.appendingPathComponent("notes.json")
        loadNotes()
    }

    func addNote() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        saveNotes()
        return note
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }

    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
    }

    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            saveNotes()
        }
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        do {
            let data = try Data(contentsOf: savePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("Failed to load notes: \(error.localizedDescription)")
        }
    }

    private func saveNotes() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(notes)
            try data.write(to: savePath, options: [.atomic])
        } catch {
            print("Failed to save notes: \(error.localizedDescription)")
        }
    }
}
