import Foundation
import Observation
import OSLog

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

// MARK: - Private Cloud Compute consent

/// The user's answer to "may Simple Text Notes use Private Cloud Compute?".
/// Persisted in `UserDefaults.standard` under `storageKey` (read via `@AppStorage` in views).
enum PrivateCloudComputeConsent: String {
    /// Not asked yet — on-device only until the user answers.
    case undecided
    /// The user allowed Private Cloud Compute.
    case granted
    /// The user declined — on-device only.
    case denied

    static let storageKey = "aiPrivateCloudComputeConsent"

    static var current: PrivateCloudComputeConsent {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .undecided
    }
}

// MARK: - SimpleTextNotesAI

@Observable
final class SimpleTextNotesAI {
    private static let logger = Logger(subsystem: "de.futural.simpletextnotes", category: "AI")

    /// Gates all AI UI: true when at least one model this app may use is ready — the
    /// on-device model, or Private Cloud Compute once the user has consented.
    static var isAvailable: Bool {
        isOnDeviceModelAvailable || usesPrivateCloudCompute
    }

    /// The on-device system model (iOS 26+, Apple Intelligence enabled, assets downloaded).
    static var isOnDeviceModelAvailable: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
#endif
        return false
    }

    /// True when the OS ships Apple's server model (iOS 27+) and this device and app may use it.
    /// Gates the consent question and the Settings toggle. Same check as HoroDrift's
    /// `HoroDriftAI.isAvailable`; deliberately independent of the on-device model.
    static var isPrivateCloudComputeSupported: Bool {
#if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) {
            return PrivateCloudComputeLanguageModel().isAvailable
        }
#endif
        return false
    }

    /// Private Cloud Compute is used only with explicit consent; otherwise everything stays on device.
    static var usesPrivateCloudCompute: Bool {
        PrivateCloudComputeConsent.current == .granted && isPrivateCloudComputeSupported
    }

    /// Runs a single prompt and returns the trimmed text response.
    ///
    /// Uses Private Cloud Compute when the user consented and it is available, and falls
    /// back to the on-device model, if that is ready, when the server request fails
    /// (offline, quota, outage).
    @MainActor
    func respond(to prompt: String, instructions: String? = nil) async throws -> String {
        guard Self.isAvailable else {
            throw SimpleTextNotesAIError.modelUnavailable
        }

#if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *), Self.usesPrivateCloudCompute {
            do {
                let session = Self.makePrivateCloudComputeSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                try Task.checkCancellation()
                guard Self.isOnDeviceModelAvailable else { throw error }
                Self.logger.error("Private Cloud Compute failed, falling back to on-device model: \(error.localizedDescription, privacy: .public)")
            }
        }

        if #available(iOS 26.0, macOS 26.0, *), Self.isOnDeviceModelAvailable {
            let session = Self.makeOnDeviceSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        throw SimpleTextNotesAIError.modelUnavailable
    }

    func wrap(_ error: Error) -> SimpleTextNotesAIError {
        if let appError = error as? SimpleTextNotesAIError {
            return appError
        }
        return .generationFailed(underlying: error)
    }

    // MARK: - Sessions

    private static func normalized(_ instructions: String?) -> String? {
        guard let instructions,
              !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return instructions
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func makeOnDeviceSession(instructions: String?) -> LanguageModelSession {
        if let instructions = normalized(instructions) {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    @available(iOS 27.0, macOS 27.0, *)
    private static func makePrivateCloudComputeSession(instructions: String?) -> LanguageModelSession {
        let model = PrivateCloudComputeLanguageModel()
        if let instructions = normalized(instructions) {
            return LanguageModelSession(model: model, instructions: instructions)
        }
        return LanguageModelSession(model: model)
    }
#endif
}
