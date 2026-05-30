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

    private let logger = Logger(subsystem: "de.futural.simpletextnotes", category: "CloudKitSync")
    private var observer: NSObjectProtocol?
    private var activeEvents: Int = 0

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
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }

        if event.endDate == nil {
            // Event is still in progress
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
                }
            }
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
