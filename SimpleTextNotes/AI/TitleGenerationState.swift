import Foundation
import Observation

@Observable
final class TitleGenerationState {
    private var generatingNoteIDs: Set<UUID> = []

    func markGenerating(_ id: UUID) {
        generatingNoteIDs.insert(id)
    }

    func markDone(_ id: UUID) {
        generatingNoteIDs.remove(id)
    }

    func isGenerating(_ id: UUID) -> Bool {
        generatingNoteIDs.contains(id)
    }
}
