import XCTest
import SwiftData
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
        XCTAssertEqual(note1.id, note2.id)
        XCTAssertEqual(note1.title, note2.title)
        XCTAssertEqual(note1.content, note2.content)
    }
}

@MainActor
final class NoteStoreTests: XCTestCase {

    private func makeStore() throws -> NoteStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return NoteStore(modelContext: container.mainContext)
    }

    func testAddNote() throws {
        let store = try makeStore()
        XCTAssertEqual(store.notes.count, 0)
        _ = store.addNote()
        XCTAssertEqual(store.notes.count, 1)
    }

    func testDeleteNote() throws {
        let store = try makeStore()
        let note = store.addNote()
        XCTAssertEqual(store.notes.count, 1)
        store.deleteNote(note)
        XCTAssertEqual(store.notes.count, 0)
    }

    func testUpdateNote() throws {
        let store = try makeStore()
        let note = store.addNote()
        note.title = "Updated Title"
        note.content = "Updated Content"
        store.updateNote(note)

        let updated = store.notes.first { $0.id == note.id }
        XCTAssertEqual(updated?.title, "Updated Title")
        XCTAssertEqual(updated?.content, "Updated Content")
    }

    func testDeleteNoteAtOffsets() throws {
        let store = try makeStore()

        _ = store.addNote()
        _ = store.addNote()
        _ = store.addNote()

        XCTAssertEqual(store.notes.count, 3)
        store.deleteNote(at: IndexSet(integer: 1))
        XCTAssertEqual(store.notes.count, 2)
    }

    func testNewNoteInsertedAtTop() throws {
        let store = try makeStore()

        let first = store.addNote()
        let second = store.addNote()

        XCTAssertEqual(store.notes.first?.id, second.id)
        XCTAssertEqual(store.notes.last?.id, first.id)
    }
}
