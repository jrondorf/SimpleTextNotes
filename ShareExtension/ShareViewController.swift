import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private static let isoFormatter = ISO8601DateFormatter()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        Task {
            var lines: [String] = []

            for item in extensionItems {
                guard let attachments = item.attachments else { continue }
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                           !text.isEmpty {
                            lines.append(text)
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                            lines.append(url.absoluteString)
                        }
                    }
                }

                if let text = item.attributedContentText?.string, !text.isEmpty {
                    lines.append(text)
                }
            }

            let content = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            if !content.isEmpty {
                saveNote(content: content)
            }

            await MainActor.run {
                complete()
            }
        }
    }

    private func saveNote(content: String) {
        let defaults = UserDefaults(suiteName: "group.de.futural.simpletextnotes")
        var pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]] ?? []
        pending.append([
            "content": content,
            "timestamp": Self.isoFormatter.string(from: Date())
        ])
        defaults?.set(pending, forKey: "pendingSharedNotes")
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
