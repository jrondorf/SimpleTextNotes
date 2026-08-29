# CLAUDE.md

Guidance for Claude Code (and other AI assistants) working in this repository.

## What this is

**SimpleTextNotes** — a plain-text note-taking app for iPhone, iPad, and Mac (via Mac
Catalyst). SwiftUI + SwiftData + CloudKit, plus an iOS Share Extension and optional
on-device Apple Intelligence features. **No external dependencies** — Apple frameworks only,
no SPM/CocoaPods/Carthage manifests anywhere in the tree.

Current release: `MARKETING_VERSION = 1.7`.

## Repository layout

```
SimpleTextNotes.xcodeproj/       # Single Xcode project, 3 targets (no workspace, no SPM)
SimpleTextNotes/                 # Main app target
  SimpleTextNotesApp.swift       # @main, ModelContainer + CloudKit setup, DatabaseErrorView fallback
  ContentView.swift              # NavigationSplitView, environment injection, trash purge,
                                 #   share-extension import/export bridge, AI auto-title for shared notes
  CloudKitSyncMonitor.swift      # @Observable, NSPersistentCloudKitContainer event observer
  Models/Note.swift              # The only @Model type
  AI/SimpleTextNotesAI.swift     # @Observable FoundationModels wrapper + error type
  AI/TitleGenerationState.swift  # @Observable store of in-flight title-generation Tasks
  Views/NoteListView.swift       # List, search, sort, pin, trash button, iCloud indicator
  Views/NoteDetailView.swift     # Title + TextEditor, toolbar actions, word count, AI actions
  Views/TrashView.swift          # Trash sheet + read-only TrashedNoteDetailView
  Views/SettingsView.swift       # Editor font style/size
  *.lproj/Localizable.strings    # 34 languages incl. RTL (ar/he), 69 keys each (en is source)
  Settings.bundle/Root.plist     # iOS Settings-app mirror of the font preferences
  Assets.xcassets/               # AppIcon (iOS + mac sizes), AccentColor
  Info.plist                     # UIBackgroundModes: remote-notification
  SimpleTextNotes.entitlements   # Debug signing
  SimpleTextNotesRelease.entitlements  # Release signing (adds aps-environment: production)
ShareExtension/                  # iOS share extension target (UIKit host + SwiftUI picker)
  ShareViewController.swift      # Everything: ShareAction, LinkPreviewCard, SharePickerView, controller
  *.lproj/Localizable.strings    # Its own 34-language table, 11 keys each (separate from the app's)
SimpleTextNotesTests/            # XCTest unit tests for the Note model (in-memory ModelContainer)
scripts/generate_icons.sh        # sips-based app-icon generator (see caveat below)
.github/copilot-instructions.md  # Parallel instruction file — keep in sync with this one
README.md                        # User-facing overview (partially stale, see below)
```

## Targets and build settings (source of truth: `project.pbxproj`)

| Target | Bundle ID | iOS min | Swift | Notes |
|---|---|---|---|---|
| `SimpleTextNotes` | `de.futural.simpletextnotes` | 26.0 | 5.9 | `SUPPORTS_MACCATALYST = YES`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, `TARGETED_DEVICE_FAMILY = "1,2"` |
| `ShareExtension` | `de.futural.simpletextnotes.shareextension` | 26.0 | 5.0 | Embedded in the app via the "Embed App Extensions" phase |
| `SimpleTextNotesTests` | `de.futural.simpletextnotes.tests` | 17.0 | 5.0 | `SUPPORTS_MACCATALYST = NO` |

- `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` on every target. **Mac support is Mac
  Catalyst, not a native macOS target** — so `canImport(UIKit)` is true on Mac too, and the
  `#elseif canImport(AppKit)` branches in shared code are effectively dead on the shipping
  Mac build. Keep them (they're harmless and document intent) but don't rely on them.
- `DEVELOPMENT_TEAM = BHQVWR45JX`, automatic signing, `CODE_SIGN_IDENTITY = "Apple Development"`.
- Debug and Release use **different entitlements files** for the app target. If you add an
  entitlement, add it to **both** `SimpleTextNotes.entitlements` and
  `SimpleTextNotesRelease.entitlements`, or Release archives will break in non-obvious ways.
- App group: `group.de.futural.simpletextnotes` (app + extension).
  CloudKit container: `iCloud.de.futural.simpletextnotes.v2`.

## Adding files to the project — read this before creating a Swift file

The two group styles in this project behave differently:

- **`SimpleTextNotes/` and `SimpleTextNotesTests/` use classic explicit file references.**
  Creating a `.swift` file on disk is *not* enough — it will silently not compile. You must
  also edit `SimpleTextNotes.xcodeproj/project.pbxproj` and add:
  1. a `PBXFileReference` entry,
  2. a `PBXBuildFile` entry,
  3. the file in the target's `PBXSourcesBuildPhase` `files` list,
  4. the file in the appropriate `PBXGroup` `children` list.

  Follow the existing ID convention (`AA0000020xx` for file refs, `AA0000010xx` for build
  files) and pick the next free number.
- **`ShareExtension/` is a `PBXFileSystemSynchronizedRootGroup`.** Files dropped in that
  directory are picked up automatically; `Info.plist` is the only membership exception.

## Build and test

Requires macOS with Xcode (`LastUpgradeCheck = 2650`). **None of this can be run in a Linux
container** — if you're working remotely, make code changes carefully and state clearly that
they are unverified rather than claiming a build passed.

```bash
open SimpleTextNotes.xcodeproj

xcodebuild -list -project SimpleTextNotes.xcodeproj
xcodebuild -scheme SimpleTextNotes -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme SimpleTextNotes -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Only `ShareExtension.xcscheme` is checked in under `xcshareddata/xcschemes/`; the
`SimpleTextNotes` scheme is auto-created by Xcode on first open. If `-scheme SimpleTextNotes`
fails on a fresh clone, open the project in Xcode once, or use `-target SimpleTextNotes`.

There is **no CI** — `.github/` contains only `copilot-instructions.md`. Nothing runs tests
automatically, so run them locally before claiming a change is verified.

`scripts/generate_icons.sh` writes into `HoroDrift/Assets.xcassets/...` — a leftover path from
another project. It does not point at this app's asset catalog; fix the path before using it.

## Data model

```swift
@Model
class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var isPinned: Bool = false
    var isTrashed: Bool = false   // mirrors deletedAt != nil

    static let trashRetentionDays: Int = 30
}
```

CloudKit-imposed rules — do not break these:
- **Every property needs a default value** (CloudKit requires all attributes to be optional
  or defaulted). No non-optional property without a default, no `@Attribute(.unique)`.
- **`isTrashed` intentionally duplicates `deletedAt != nil`.** Predicates over an optional
  `Date` don't work reliably against the CloudKit-backed store, so all queries filter on the
  `Bool`. Any code path that changes trash state must set **both** fields:
  ```swift
  note.deletedAt = Date();  note.isTrashed = true    // to trash
  note.deletedAt = nil;     note.isTrashed = false   // to restore
  ```
- Active-notes query: `@Query(filter: #Predicate<Note> { $0.isTrashed == false })`
  (used in both `ContentView` and `NoteListView`). Trash query is the `== true` mirror.

### Trash / soft-delete

User-facing "delete" never hard-deletes. Only two places call `modelContext.delete(_:)` on a
note: `TrashView` (permanent delete / empty trash, both behind a confirmation) and
`ContentView.purgeOldTrashNotes()`. The purge runs in `.task` at launch, fetches all trashed
notes, and filters in memory for `deletedAt < now - trashRetentionDays`.

## App architecture

```
SimpleTextNotesApp (@main)
└─ ModelContainer(cloudKitDatabase: .private("iCloud.de.futural.simpletextnotes.v2"))
   │  (container init failure → DatabaseErrorView instead of a crash)
   └─ ContentView — NavigationSplitView, owns @State selectedNote: Note?
      │  injects TitleGenerationState, SimpleTextNotesAI, CloudKitSyncMonitor via .environment
      ├─ NoteListView(selectedNote:)
      ├─ NoteDetailView(note:selectedNote:)  .id(note.id)
      ├─ TrashView (sheet)
      └─ SettingsView (sheet)
```

- State: `@State` for local, `@Binding` for parent-owned, `@Bindable` for the `Note` model,
  `@Query` for fetches, `@Environment(\.modelContext)` for insert/delete,
  `@Environment(Type.self)` for the three injected `@Observable` objects.
- `selectedNote` is a `Note?` (direct model reference), not a UUID. Set it to `nil` before
  trashing or deleting the note it points at. `NoteListView.onChange(of: notes)` also clears
  a stale selection when a note disappears via CloudKit sync from another device.
- Never call `modelContext.save()` in app code — SwiftData autosaves. (Tests do call `save()`
  explicitly; that's fine.)
- After any `await` that follows a model mutation, re-check `note.modelContext != nil` before
  touching the note — it may have been deleted during the async gap.
- `note.updatedAt` is **debounced**, not written per keystroke: `NoteDetailView`'s title and
  content `onChange` handlers call `scheduleTimestampUpdate()`, which coalesces the write for
  one second, and `onDisappear` calls `commitTimestampUpdate()` to flush it. Anything that
  mutates content programmatically (paste, AI) still stamps `updatedAt` directly.

### Persisted preferences (`@AppStorage`)

| Key | Type | Default | Used by |
|---|---|---|---|
| `editorFontName` | String (`system`/`monospaced`/`serif`) | `system` | `SettingsView`, `NoteDetailView` |
| `editorFontSize` | Double (14/16/18/20) | `16.0` | `SettingsView`, `NoteDetailView` |
| `noteSortOption` | String (`updatedAt`/`createdAt`/`title`) | `updatedAt` | `NoteListView` |

The font keys are mirrored in `SimpleTextNotes/Settings.bundle/Root.plist` so they're also
editable from the iOS Settings app. **Changing a font option means editing both places**, and
`Root.plist` values are hardcoded English (its `StringsTable` is `Root`, which has no
`.strings` files). Editor font sizes go through `@ScaledMetric` (`effectiveFontSize`) so they
respect Dynamic Type — never hardcode a numeric size in the editor.

### Sorting and search

Both are client-side in `NoteListView.displayedNotes`: filter by `searchText` over title and
content, then sort with pinned notes always first, then by the active `NoteSortOption`
(`title` uses `localizedCompare`). Deliberate — avoids needing a `@Query` per sort order.

## Apple Intelligence (FoundationModels)

All AI code is doubly gated so the app works on devices without Apple Intelligence:

```swift
#if canImport(FoundationModels)
if #available(iOS 26.0, macOS 26.0, *) { /* AI code */ }
#endif
```

- `SimpleTextNotesAI` — `@Observable`, injected from `ContentView`. `isAvailable` (static)
  gates all AI UI; `makeSession(instructions:)` builds the `LanguageModelSession`;
  `wrap(_:)` normalizes errors to `SimpleTextNotesAIError`. **Never construct
  `LanguageModelSession` directly** and never instantiate `SimpleTextNotesAI` inside a view —
  read it from `@Environment(SimpleTextNotesAI.self)`.
- `TitleGenerationState` — `@Observable`, holds the in-flight `Task` objects *and* the set of
  note IDs showing the animated-dots indicator. Title-generation tasks must be stored here via
  `startTask(_:for:showIndicator:)` (never in view `@State`) so they outlive the view;
  finish with `markDone(_:)`, abandon with `cancelTask(for:)`.
- Two AI entry points:
  - **Auto-title** — `NoteDetailView.onDisappear` when the title is empty, and
    `ContentView.scheduleAutoTitle(for:)` for notes created by the share extension. Prompt and
    limits (`maxTitleLength = 60`, `maxContentLengthForTitleGeneration = 1000`) are duplicated
    in both files; keep them in sync if you change one.
  - **Sparkles button** in `NoteDetailView` — appends generated content, shows an alert if the
    note is empty, surfaces failures via the `aiError` alert.
- Auto-title failures are swallowed on purpose (the note just keeps an empty title).

## Share extension bridge

The extension does **not** touch SwiftData. It talks to the app through
`UserDefaults(suiteName: "group.de.futural.simpletextnotes")` with two keys:

| Key | Writer | Reader | Shape |
|---|---|---|---|
| `notesList` | app (`ContentView.syncNotesList`, on launch and on every `notes` change) | extension (`loadNotesList`) | `[[String: String]]` with `id`, `title`, `updatedAt` (ISO 8601) |
| `pendingSharedNotes` | extension (`saveNote`) | app (`ContentView.importPendingSharedNotes`) | `[[String: String]]` with `content`, `timestamp`, `action` (`new`/`append`), and `noteId` when appending |

The app drains `pendingSharedNotes` on launch and on `willEnterForeground`, popping **one entry
at a time** (`ContentView.popPendingSharedNote`) so an entry only leaves the inbox once its note
exists — never read the whole array and clear the key up front. Both sides wrap their
read-modify-write in `withSharedInboxLock`, an `NSFileCoordinator` write on
`pendingSharedNotes.lock` in the app-group container; the helper is duplicated in `ContentView`
and `ShareViewController` (no shared module) and both copies must keep using the same lock file.
Appends insert a blank line (`\n\n`) between old and new content; an `append` whose target note
no longer exists falls back to creating a new note. If you change either payload shape, change
both sides — there is no versioning on these dictionaries.

The extension is UIKit-hosted: `ShareViewController` embeds `SharePickerView` as a child view
controller with edge constraints (**not** as a presented sheet — presenting broke it on
Catalyst; see commit `d2e2e92`). It has its **own** `Localizable.strings` table under
`ShareExtension/*.lproj` — 34 locales, 11 `share_*` keys, resolved against the appex bundle, and
entirely separate from the app's table (a key added to one is not visible to the other). The
literal `"SimpleTextNotes"` in the header bar is the product name and is deliberately not a key.
Because `ShareExtension/` is a synchronized root group, new `.lproj` folders are picked up with
no `project.pbxproj` edit — but they only build for locales listed in the project's
`knownRegions`.

## Localization

- 34 languages under `SimpleTextNotes/*.lproj/Localizable.strings`, 69 keys each; `en` is the
  development language and the source of truth. `SWIFT_EMIT_LOC_STRINGS = YES`. All 34 files
  currently carry an identical key set, and every key referenced from Swift exists in it —
  keep it that way. Note that the 22 translation files share a key **order** that differs from
  `en` (`ok_button` and the three `ai_*` help/failure keys sit elsewhere); follow the
  translations' order, not `en`'s, when adding a file.
- The share extension has a **second, independent table** (`ShareExtension/*.lproj`, 11 keys).
  Its keys are all prefixed `share_`; four of them intentionally duplicate app values
  (`share_new_note_title`, `share_untitled_note`, `share_cancel_button`, `share_done_button`) —
  keep them in step with the app wording when you change either.
- **Portuguese is `pt`, not `pt-BR`.** Apple treats a bare `pt` as Brazilian Portuguese, so
  `pt.lproj` carries the Brazilian wording and covers Brazil *and* any Portuguese locale with
  no closer match; `pt-PT.lproj` overrides it with European wording (Definições/Lixo/Partilhar/
  Apagar, "A sincronizar", base de dados, aplicação). App Store Connect is a separate axis and
  still lists Portuguese (Brazil) and Portuguese (Portugal) individually.
- **`ar` and `he` are RTL.** Shipping those `.lproj` directories is what makes iOS flip
  `layoutDirection` — there is no separate switch. The UI mirrors for free because no view
  hardcodes a side: all edge padding is `.horizontal`/`.vertical`, alignments are
  `.leading`/`.trailing`, and the only directional SF Symbols (`chevron.right`,
  `arrow.uturn.backward`) carry the auto-mirroring trait. Keep it that way — never introduce
  `.left`/`.right`, `.offset(x:)`, or `semanticContentAttribute`.
- Views pass the **key** directly to SwiftUI (`Text("untitled_note")`,
  `Label("copy_button", systemImage:)`, `.navigationTitle("trash_navigation_title")`) and use
  `String(localized:)` when a `String` is needed imperatively, plus
  `String(format: String(localized: "word_count_format"), …)` for the formatted ones.
- **Adding a user-facing string means adding the key to all 34 files** with a translation, not
  just `en` — in whichever of the two tables the code reads it from. Keep the `/* comment */`
  above each key and the existing key order.
- Keys are `snake_case` and suffixed by role: `_button`, `_title`, `_message`, `_label`,
  `_prompt`, `_placeholder`, `_format`, `_navigation_title`.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New note |
| ⌘⌫ | Move current note to trash |
| ⇧⌘C | Copy note (title + content) |
| ⇧⌘V | Paste clipboard (appended) |
| ⇧⌘S | Share note |
| ⇧⌘P | Pin / unpin |

Programmatic content mutations (paste, AI generation) register an undo with
`@Environment(\.undoManager)` **before** mutating `note.content`, with
`setActionName(String(localized:…))`. Do the same for any new mutation you add; `TextEditor`
typing undo is handled by the system.

## iCloud sync indicator

`CloudKitSyncMonitor` observes `NSPersistentCloudKitContainer.eventChangedNotification`,
counts in-flight events, logs via `OSLog` (subsystem `de.futural.simpletextnotes`, category
`CloudKitSync`), and exposes `syncState: CloudKitSyncState` (`.notSyncing`, `.syncing`,
`.synced`, `.error`). `NoteListView.iCloudSyncIndicator` maps those four states to toolbar
SF Symbols with accessibility labels. `.synced` is transient — `scheduleReturnToIdle()` drops
back to `.notSyncing` after `syncedDisplayDuration` (3s) so the checkmark doesn't sit in the
toolbar for the rest of the session; a new in-flight event cancels that pending transition.

## Conventions

- Types `PascalCase`, members `camelCase`, one primary type per file named after it, `private`
  on everything not used outside its file, `// MARK: -` to section longer files.
- Declarative SwiftUI; extract subviews or computed `@ViewBuilder` properties instead of
  growing a `body`. Shared `DateFormatter`s are `private static let` on the view.
- Platform branches use `#if canImport(UIKit) / #elseif canImport(AppKit)` for framework types
  and `#if os(iOS)` for iOS-only modifiers such as `.navigationBarTitleDisplayMode`.
- `ContentUnavailableView` for empty states, `ShareLink` for sharing.

### Do not

- Use Core Data APIs for app data (SwiftData only — `CoreData` is imported solely for the
  CloudKit event notification in `CloudKitSyncMonitor`).
- Add third-party dependencies.
- Use `ObservableObject`/`@ObservedObject`/`@StateObject` — this codebase is `@Observable` +
  `@Bindable` throughout.
- Call `modelContext.save()` in app code, or hard-delete a note outside trash purge / explicit
  permanent delete.
- Set `deletedAt` without also setting `isTrashed` (or vice versa).
- Store title-generation `Task`s in view `@State`.
- Hardcode a user-facing English string in the main app — add a localized key instead.

## Housekeeping notes for anyone editing this repo

- `.gitignore` contains only `.DS_Store`. Xcode user state
  (`xcuserdata/…/UserInterfaceState.xcuserstate`, `xcschememanagement.plist`) **is tracked**
  and churns on every Xcode session. Don't sweep it into unrelated commits.
- `README.md` predates the trash, AI, settings, localization, and share-extension work — its
  feature list, project tree, and "iOS 17.0+" requirement no longer match the project. Treat
  this file and `project.pbxproj` as authoritative.
- `.github/copilot-instructions.md` covers the same ground for GitHub Copilot. When you change
  a convention here, update it there too. A few of its claims have drifted from the code —
  the sync monitor is now `CloudKitSyncMonitor` in its own file with a four-state enum (not an
  inline `CloudSyncMonitor` with `isSyncing`), the trash purge filters in memory rather than
  by predicate, and queries key off `isTrashed` rather than `deletedAt`.
- `SimpleTextNotesTests.swift` constructs some descriptors as `FetchDescriptor(filter:)` while
  app code uses `FetchDescriptor(predicate:)`. Verify in Xcode before copying either form into
  new code.
