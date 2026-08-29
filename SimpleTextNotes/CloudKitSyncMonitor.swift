//
//  CloudKitSyncMonitor.swift
//  SimpleTextNotes
//
//  Observes NSPersistentCloudKitContainer sync events, logs errors, and
//  exposes the current sync state for display in the UI.
//

import CoreData
import OSLog
import Observation

enum CloudKitSyncState {
    case notSyncing
    case syncing
    case synced
    case error
}

@Observable
final class CloudKitSyncMonitor {
    private(set) var syncState: CloudKitSyncState = .notSyncing

    /// How long the "synced" checkmark stays up before the indicator goes back to idle.
    private static let syncedDisplayDuration: TimeInterval = 3

    private let logger = Logger(subsystem: "de.futural.simpletextnotes", category: "CloudKitSync")
    private var observer: NSObjectProtocol?
    private var activeEvents: Int = 0
    private var idleTask: Task<Void, Never>?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncEvent(notification)
        }
    }

    deinit {
        idleTask?.cancel()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }

        if event.endDate == nil {
            // Event is still in progress
            idleTask?.cancel()
            idleTask = nil
            activeEvents += 1
            syncState = .syncing
        } else {
            activeEvents = max(0, activeEvents - 1)
            if let error = event.error {
                logger.error("CloudKit sync error [\(self.typeName(event.type), privacy: .public)]: \(error)")
                syncState = .error
            } else if event.succeeded {
                logger.debug("CloudKit sync succeeded [\(self.typeName(event.type), privacy: .public)]")
                if activeEvents == 0 {
                    syncState = .synced
                    scheduleReturnToIdle()
                }
            }
        }
    }

    /// Drop back to the neutral icon so the checkmark doesn't sit in the toolbar
    /// for the rest of the session.
    private func scheduleReturnToIdle() {
        idleTask?.cancel()
        idleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.syncedDisplayDuration))
            guard !Task.isCancelled, let self, self.activeEvents == 0 else { return }
            guard case .synced = self.syncState else { return }
            self.syncState = .notSyncing
        }
    }

    private func typeName(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup:  return "setup"
        case .import: return "import"
        case .export: return "export"
        @unknown default: return "unknown(\(type.rawValue))"
        }
    }
}
