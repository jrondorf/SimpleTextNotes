import XCTest
@testable import SimpleTextNotes

final class NoteTests: XCTestCase {

    func testNoteCreation() {
        let note = Note(title: "Test", content: "Hello")
        XCTAssertEqual(note.title, "Test")
        XCTAssertEqual(note.content, "Hello")
        XCTAssertNotNil(note.id)
        XCTAssertNotNil(note.createdAt)
    }

    func testNoteDefaultValues() {
        let note = Note()
        XCTAssertEqual(note.title, "")
        XCTAssertEqual(note.content, "")
    }

    func testNoteEquality() {
        let id = UUID()
        let date = Date()
        let note1 = Note(id: id, title: "A", content: "B", createdAt: date)
        let note2 = Note(id: id, title: "A", content: "B", createdAt: date)
        XCTAssertEqual(note1, note2)
    }

    func testNoteCodable() throws {
        let note = Note(title: "Coded", content: "Some content")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(note)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(note, decoded)
    }
}

final class NoteStoreTests: XCTestCase {

    func testAddNote() {
        let store = NoteStore()
        let initialCount = store.notes.count
        _ = store.addNote()
        XCTAssertEqual(store.notes.count, initialCount + 1)
    }

    func testDeleteNote() {
        let store = NoteStore()
        let note = store.addNote()
        let countAfterAdd = store.notes.count
        store.deleteNote(note)
        XCTAssertEqual(store.notes.count, countAfterAdd - 1)
        XCTAssertFalse(store.notes.contains(where: { $0.id == note.id }))
    }

    func testUpdateNote() {
        let store = NoteStore()
        var note = store.addNote()
        note.title = "Updated Title"
        note.content = "Updated Content"
        store.updateNote(note)

        let updated = store.notes.first { $0.id == note.id }
        XCTAssertEqual(updated?.title, "Updated Title")
        XCTAssertEqual(updated?.content, "Updated Content")
    }

    func testDeleteNoteAtOffsets() {
        let store = NoteStore()
        // Clear any existing notes by deleting them
        while !store.notes.isEmpty {
            store.deleteNote(at: IndexSet(integer: 0))
        }

        _ = store.addNote()
        _ = store.addNote()
        _ = store.addNote()

        XCTAssertEqual(store.notes.count, 3)
        store.deleteNote(at: IndexSet(integer: 1))
        XCTAssertEqual(store.notes.count, 2)
    }

    func testNewNoteInsertedAtTop() {
        let store = NoteStore()
        while !store.notes.isEmpty {
            store.deleteNote(at: IndexSet(integer: 0))
        }

        let first = store.addNote()
        let second = store.addNote()

        XCTAssertEqual(store.notes.first?.id, second.id)
        XCTAssertEqual(store.notes.last?.id, first.id)
    }
}
