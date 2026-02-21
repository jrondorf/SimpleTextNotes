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

    @MainActor
    func testInsertAndFetchNote() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let note = Note(title: "SwiftData Test", content: "Content")
        context.insert(note)
        try context.save()

        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let notes = try context.fetch(descriptor)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "SwiftData Test")
    }

    @MainActor
    func testDeleteNote() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let note = Note(title: "To Delete", content: "Content")
        context.insert(note)
        try context.save()

        context.delete(note)
        try context.save()

        let descriptor = FetchDescriptor<Note>()
        let notes = try context.fetch(descriptor)
        XCTAssertEqual(notes.count, 0)
    }

    @MainActor
    func testUpdateNote() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let note = Note(title: "Original", content: "Content")
        context.insert(note)
        try context.save()

        note.title = "Updated Title"
        note.content = "Updated Content"
        try context.save()

        let descriptor = FetchDescriptor<Note>()
        let notes = try context.fetch(descriptor)
        XCTAssertEqual(notes.first?.title, "Updated Title")
        XCTAssertEqual(notes.first?.content, "Updated Content")
    }
}
