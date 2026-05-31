import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Share Action

enum ShareAction {
    case newNote
    case appendToNote(id: String)
}

// MARK: - Share Picker View

struct SharePickerView: View {
    let sharedContent: String
    let existingNotes: [(id: String, title: String)]
    let onSave: (ShareAction) -> Void
    let onCancel: () -> Void

    enum ShareMode {
        case newNote, appendToNote
    }

    @State private var mode: ShareMode = .newNote
    @State private var selectedNoteId: String? = nil

    private var canSave: Bool {
        switch mode {
        case .newNote:
            return true
        case .appendToNote:
            return existingNotes.isEmpty || selectedNoteId != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(sharedContent)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                } header: {
                    Text("Shared Content")
                }

                Section {
                    Picker("Action", selection: $mode) {
                        Text("New Note").tag(ShareMode.newNote)
                        Text("Append to Note").tag(ShareMode.appendToNote)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                if mode == .appendToNote {
                    if existingNotes.isEmpty {
                        Section {
                            Text("No existing notes found. The content will be saved as a new note.")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                    } else {
                        Section("Select Note") {
                            ForEach(existingNotes, id: \.id) { note in
                                Button {
                                    selectedNoteId = note.id
                                } label: {
                                    HStack {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedNoteId == note.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save to Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let action: ShareAction
                        switch mode {
                        case .newNote:
                            action = .newNote
                        case .appendToNote:
                            if let id = selectedNoteId {
                                action = .appendToNote(id: id)
                            } else {
                                action = .newNote
                            }
                        }
                        onSave(action)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - ShareViewController

class ShareViewController: UIViewController {

    private static let isoFormatter = ISO8601DateFormatter()
    private static let appGroupID = "group.de.futural.simpletextnotes"

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

            await MainActor.run {
                if content.isEmpty {
                    complete()
                } else {
                    presentPicker(for: content)
                }
            }
        }
    }

    private func presentPicker(for content: String) {
        let existingNotes = loadNotesList()

        let hostingController = UIHostingController(
            rootView: SharePickerView(
                sharedContent: content,
                existingNotes: existingNotes,
                onSave: { [weak self] action in
                    self?.saveNote(content: content, action: action)
                    self?.dismiss(animated: true) {
                        self?.complete()
                    }
                },
                onCancel: { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.complete()
                    }
                }
            )
        )

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(hostingController, animated: true)
    }

    private func loadNotesList() -> [(id: String, title: String)] {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard let list = defaults?.array(forKey: "notesList") as? [[String: String]] else {
            return []
        }
        return list.compactMap { dict in
            guard let id = dict["id"] else { return nil }
            return (id: id, title: dict["title"] ?? "")
        }
    }

    private func saveNote(content: String, action: ShareAction) {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        var pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]] ?? []
        var entry: [String: String] = [
            "content": content,
            "timestamp": Self.isoFormatter.string(from: Date())
        ]
        switch action {
        case .newNote:
            entry["action"] = "new"
        case .appendToNote(let id):
            entry["action"] = "append"
            entry["noteId"] = id
        }
        pending.append(entry)
        defaults?.set(pending, forKey: "pendingSharedNotes")
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
