import Foundation
import SwiftData

@Model
class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var isPinned: Bool = false
    var isTrashed: Bool = false

    static let trashRetentionDays: Int = 30

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.deletedAt = nil
        self.isPinned = false
        self.isTrashed = false
    }
}
