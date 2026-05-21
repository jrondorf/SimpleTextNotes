import Foundation
import Observation

@Observable
final class TitleGenerationState {
    private var generatingNoteIDs: Set<UUID> = []
    private var tasks: [UUID: Task<Void, Never>] = [:]

    /// Start a generation task for the given note, cancelling any prior task for the same note.
    func startTask(_ task: Task<Void, Never>, for id: UUID, showIndicator: Bool) {
        tasks[id]?.cancel()
        tasks[id] = task
        if showIndicator {
            generatingNoteIDs.insert(id)
        }
    }

    /// Mark generation complete and release the stored task.
    func markDone(_ id: UUID) {
        tasks.removeValue(forKey: id)
        generatingNoteIDs.remove(id)
    }

    /// Cancel and discard the task for the given note (e.g. note was deleted).
    func cancelTask(for id: UUID) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        generatingNoteIDs.remove(id)
    }

    func isGenerating(_ id: UUID) -> Bool {
        generatingNoteIDs.contains(id)
    }
}
