import UIKit
import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

// MARK: - Share Action

enum ShareAction {
    case newNote
    case appendToNote(id: String)
}

// MARK: - Link Preview Card

struct LinkPreviewCard: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(url: url)
        let provider = LPMetadataProvider()
        context.coordinator.provider = provider
        provider.startFetchingMetadata(for: url) { metadata, _ in
            guard let metadata else { return }
            DispatchQueue.main.async {
                linkView.metadata = metadata
            }
        }
        return linkView
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var provider: LPMetadataProvider?
    }
}

// MARK: - Share Picker View

struct SharePickerView: View {
    let sharedContent: String
    let existingNotes: [(id: String, title: String)]
    let onSave: (ShareAction, String) -> Void
    let onCancel: () -> Void

    @State private var additionalText: String = ""
    @State private var selectedNoteId: String? = nil
    @State private var showNotePicker: Bool = false

    private var sharedURL: URL? {
        guard let url = URL(string: sharedContent),
              let scheme = url.scheme,
              scheme.hasPrefix("http") else { return nil }
        return url
    }

    private var destinationTitle: String {
        if let id = selectedNoteId,
           let note = existingNotes.first(where: { $0.id == id }) {
            return note.title.isEmpty ? "Untitled" : note.title
        }
        return "New Note"
    }

    private var destinationSubtitle: String {
        selectedNoteId != nil
            ? "This content will be appended to the selected note."
            : "This content will be saved in a new note."
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    destinationSection
                    contentInputArea
                }
                .padding()
            }
        }
        .sheet(isPresented: $showNotePicker) {
            notePickerSheet
        }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            Spacer()
            Text("SimpleTextNotes")
                .font(.headline)
            Spacer()
            Button {
                let action: ShareAction = selectedNoteId.map { .appendToNote(id: $0) } ?? .newNote
                onSave(action, additionalText)
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(Color(.label).opacity(1))
                    .colorScheme(.light)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAVE TO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            Button {
                showNotePicker = true
            } label: {
                HStack {
                    Text(destinationTitle)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(destinationSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    private var contentInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if additionalText.isEmpty {
                    Text("Add text to note...")
                        .font(.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $additionalText)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
            }

            Divider()

            if let url = sharedURL {
                LinkPreviewCard(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(sharedContent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notePickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    selectedNoteId = nil
                    showNotePicker = false
                } label: {
                    HStack {
                        Text("New Note")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedNoteId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                if !existingNotes.isEmpty {
                    Section("Existing Notes") {
                        ForEach(existingNotes, id: \.id) { note in
                            Button {
                                selectedNoteId = note.id
                                showNotePicker = false
                            } label: {
                                HStack {
                                    Text(note.title.isEmpty ? "Untitled" : note.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedNoteId == note.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showNotePicker = false }
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
                onSave: { [weak self] action, additionalText in
                    self?.saveNote(content: content, additionalText: additionalText, action: action)
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

    private func saveNote(content: String, additionalText: String, action: ShareAction) {
        let trimmed = additionalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = trimmed.isEmpty ? content : trimmed + "\n" + content

        let defaults = UserDefaults(suiteName: Self.appGroupID)
        var pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]] ?? []
        var entry: [String: String] = [
            "content": combined,
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
