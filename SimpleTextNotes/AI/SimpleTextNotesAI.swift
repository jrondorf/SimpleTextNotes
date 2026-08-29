import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum SimpleTextNotesAIError: Error {
    case modelUnavailable
    case generationFailed(underlying: Error)
}

extension SimpleTextNotesAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return String(localized: "ai_error_unavailable_message")
        case .generationFailed(let underlying):
            return String(format: String(localized: "ai_error_generation_failed_format"),
                          underlying.localizedDescription)
        }
    }
}

@Observable
final class SimpleTextNotesAI {
    static var isAvailable: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
#endif
        return false
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    func makeSession(instructions: String? = nil) throws -> LanguageModelSession {
        guard Self.isAvailable else {
            throw SimpleTextNotesAIError.modelUnavailable
        }

        if let instructions, !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LanguageModelSession(instructions: instructions)
        }

        return LanguageModelSession()
    }
#endif

    func wrap(_ error: Error) -> SimpleTextNotesAIError {
        if let appError = error as? SimpleTextNotesAIError {
            return appError
        }
        return .generationFailed(underlying: error)
    }
}
