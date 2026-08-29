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
            DispatchQueue.main.async { [weak linkView] in
                linkView?.metadata = metadata
            }
        }
        return linkView
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var provider: LPMetadataProvider?
        deinit { provider?.cancel() }
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
            return note.title.isEmpty ? String(localized: "share_untitled_note") : note.title
        }
        return String(localized: "share_new_note_title")
    }

    private var destinationSubtitle: String {
        selectedNoteId != nil
            ? String(localized: "share_append_message")
            : String(localized: "share_new_note_message")
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
            .accessibilityLabel(Text("share_cancel_button"))
            Spacer()
            Text(verbatim: "Simple Text Notes")
                .font(.headline)
            Spacer()
            Button {
                let action: ShareAction = selectedNoteId.map { .appendToNote(id: $0) } ?? .newNote
                onSave(action, additionalText)
            } label: {
                Text("share_save_button")
                    .font(.headline)
                    .foregroundStyle(.black)
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
            Text("share_save_to_label")
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
                    Text("share_text_placeholder")
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
                        Text("share_new_note_title")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedNoteId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                if !existingNotes.isEmpty {
                    Section("share_existing_notes_label") {
                        ForEach(existingNotes, id: \.id) { note in
                            Button {
                                selectedNoteId = note.id
                                showNotePicker = false
                            } label: {
                                HStack {
                                    Text(note.title.isEmpty ? String(localized: "share_untitled_note") : note.title)
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
            .navigationTitle("share_save_to_navigation_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("share_done_button") { showNotePicker = false }
                }
            }
        }
    }
}

// MARK: - ShareViewController

class ShareViewController: UIViewController {

    private static let isoFormatter = ISO8601DateFormatter()
    private static let appGroupID = "group.de.futural.simpletextnotes"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

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
                var itemLines: [String] = []

                for provider in item.attachments ?? [] {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                           !text.isEmpty {
                            itemLines.append(text)
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                            itemLines.append(url.absoluteString)
                        }
                    }
                }

                // Most share sources put the same text in both an attachment and
                // attributedContentText — only use the latter as a fallback, or the
                // note ends up with the shared text twice.
                if itemLines.isEmpty, let text = item.attributedContentText?.string, !text.isEmpty {
                    itemLines.append(text)
                }

                lines.append(contentsOf: itemLines)
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
                    self?.complete()
                },
                onCancel: { [weak self] in
                    self?.complete()
                }
            )
        )

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
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
        let combined = trimmed.isEmpty ? content : trimmed + "\n\n" + content

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
        // The app drains this list concurrently; coordinate so an append never
        // races a drain and loses either side's changes.
        Self.withSharedInboxLock {
            let defaults = UserDefaults(suiteName: Self.appGroupID)
            var pending = defaults?.array(forKey: "pendingSharedNotes") as? [[String: String]] ?? []
            pending.append(entry)
            defaults?.set(pending, forKey: "pendingSharedNotes")
        }
    }

    // MARK: - Shared inbox coordination

    /// Sentinel file in the shared container used to serialize `pendingSharedNotes`
    /// access between this extension and the app. Mirrored in `ContentView`.
    private static let sharedInboxLockURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: ShareViewController.appGroupID)?
        .appendingPathComponent("pendingSharedNotes.lock")

    private static func withSharedInboxLock(_ body: @escaping () -> Void) {
        guard let url = sharedInboxLockURL else {
            body()
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        var didRun = false
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { _ in
            body()
            didRun = true
        }
        // Coordination itself failed — better an uncoordinated write than a dropped share.
        if !didRun { body() }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
