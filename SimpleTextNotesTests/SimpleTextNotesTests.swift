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
        XCTAssertNotNil(note.updatedAt)
        XCTAssertEqual(note.createdAt, note.updatedAt)
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

    func testNoteDefaultTrashState() {
        let note = Note()
        XCTAssertNil(note.deletedAt)
        XCTAssertFalse(note.isTrashed)
    }

    @MainActor
    func testMoveNoteToTrash() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let note = Note(title: "Trash Test", content: "Content")
        context.insert(note)
        try context.save()

        note.deletedAt = Date()
        note.isTrashed = true
        try context.save()

        let trashedDescriptor = FetchDescriptor<Note>(filter: #Predicate<Note> { $0.isTrashed == true })
        let trashedNotes = try context.fetch(trashedDescriptor)
        XCTAssertEqual(trashedNotes.count, 1)
        XCTAssertNotNil(trashedNotes.first?.deletedAt)
        XCTAssertTrue(trashedNotes.first?.isTrashed ?? false)

        let activeDescriptor = FetchDescriptor<Note>(filter: #Predicate<Note> { $0.isTrashed == false })
        let activeNotes = try context.fetch(activeDescriptor)
        XCTAssertEqual(activeNotes.count, 0)
    }

    @MainActor
    func testRestoreNoteFromTrash() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let note = Note(title: "Restore Test", content: "Content")
        note.deletedAt = Date()
        note.isTrashed = true
        context.insert(note)
        try context.save()

        note.deletedAt = nil
        note.isTrashed = false
        try context.save()

        let activeDescriptor = FetchDescriptor<Note>(filter: #Predicate<Note> { $0.isTrashed == false })
        let activeNotes = try context.fetch(activeDescriptor)
        XCTAssertEqual(activeNotes.count, 1)
        XCTAssertNil(activeNotes.first?.deletedAt)
        XCTAssertFalse(activeNotes.first?.isTrashed ?? true)
    }

    @MainActor
    func testUpdateNoteUpdatesTimestamp() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = container.mainContext

        let createdAt = Date(timeIntervalSinceNow: -60)
        let note = Note(title: "Original", content: "Content", createdAt: createdAt)
        context.insert(note)
        try context.save()

        let updatedAt = Date()
        note.title = "Updated Title"
        note.updatedAt = updatedAt
        try context.save()

        let descriptor = FetchDescriptor<Note>()
        let notes = try context.fetch(descriptor)
        let fetched = try XCTUnwrap(notes.first)
        XCTAssertEqual(fetched.title, "Updated Title")
        XCTAssertEqual(fetched.createdAt, createdAt)
        XCTAssertGreaterThanOrEqual(fetched.updatedAt, updatedAt)
    }
}
