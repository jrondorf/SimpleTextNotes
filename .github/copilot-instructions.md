# GitHub Copilot Instructions — Simple Text Notes

## Project Overview

**Simple Text Notes** is a lightweight, cross-platform note-taking app for iOS, iPadOS, and macOS. It is built entirely with native Apple frameworks and has no external dependencies.

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (declarative)
- **Data Persistence:** SwiftData (`@Model`, `@Query`, `ModelContainer`, `ModelContext`)
- **Cloud Sync:** CloudKit via iCloud (configured through entitlements)
- **Testing:** XCTest
- **Minimum Deployment:** iOS 17.0 / macOS 14.0 (Sonoma)
- **Architecture:** arm64 only

## Architecture

The app follows **MVVM with reactive programming** using SwiftUI property wrappers:

```
SimpleTextNotesApp (@main)
  └─ ModelContainer (SwiftData + CloudKit)
       └─ ContentView (NavigationSplitView)
             ├─ NoteListView   — @Query, search/filter/sort, swipe-to-delete, pin, trash toolbar, sync indicator
             ├─ NoteDetailView — @Bindable, edit title/content, clipboard, share, delete, pin, AI button, word count
             └─ TrashView      — sheet with NavigationStack; soft-deleted notes readable; restore / purge actions
```

- `@Model` — marks `Note` as a SwiftData persistent class
- `@Query` — fetches and observes notes reactively in `NoteListView`
- `@Bindable` — enables two-way binding between `NoteDetailView` and a `Note` instance
- `@Binding` — passes state between parent and child views
- `onChange()` — triggers side effects like updating the `updatedAt` timestamp
- `@Observable` — used by `SimpleTextNotesAI`, `TitleGenerationState`, and `CloudSyncMonitor` for reactive state

## Project File Structure

```
SimpleTextNotes/
├── SimpleTextNotesApp.swift   # @main app entry point, ModelContainer setup, DatabaseErrorView
├── ContentView.swift          # NavigationSplitView, selectedNote state, trash purge on launch,
│                              # CloudSyncMonitor class (inline), environment injection
├── Models/
│   └── Note.swift             # SwiftData @Model (id, title, content, createdAt, updatedAt, deletedAt, isPinned)
├── AI/
│   ├── SimpleTextNotesAI.swift    # @Observable wrapper around FoundationModels (Apple Intelligence)
│   └── TitleGenerationState.swift # @Observable class; stores Tasks and in-progress IDs for AI title generation
├── Views/
│   ├── NoteListView.swift     # List with @Query, search, sort menu, pin swipe, trash toolbar, sync indicator
│   ├── NoteDetailView.swift   # Editor with toolbar: pin, share, AI, copy, paste, delete; word count footer
│   ├── TrashView.swift        # Sheet with NavigationLink → TrashedNoteDetailView; restore / empty trash
│   └── SettingsView.swift     # App settings sheet (font style + size)
└── SimpleTextNotesTests/
    └── SimpleTextNotesTests.swift  # XCTest unit tests for Note model
```

## Coding Conventions

### Naming
- **Types** (structs, classes, enums): `PascalCase` — e.g., `NoteDetailView`, `NoteListView`
- **Variables and properties**: `camelCase` — e.g., `selectedNote`, `displayedNotes`, `updatedAt`
- **Private members**: marked with `private` keyword
- **File names**: match the primary type they contain, using `PascalCase`

### SwiftUI Patterns
- Use `@State` for local view state
- Use `@Binding` for state passed in from a parent
- Use `@Bindable` for two-way binding to a SwiftData `@Model` object
- Use `@Query` for fetching and observing SwiftData results
- Use `@Environment(\.modelContext)` to access the data context for insert/delete
- Use `@Environment(\.undoManager)` to register undos for programmatic content changes
- Use `@ScaledMetric(relativeTo:)` for font sizes that respect Dynamic Type
- Prefer computed properties for derived values (e.g., `displayedNotes`)
- Use `.searchable()` modifier with a `searchText` state variable for search
- Use `ContentUnavailableView` for empty or unselected states
- Use `ShareLink` for share/export functionality

### SwiftData Patterns
- Define models with the `@Model` macro on a `class` (not `struct`)
- All model properties should have default values
- Access `ModelContext` via `@Environment(\.modelContext)`
- Use `modelContext.insert()` to add and `modelContext.delete()` to remove objects
- No explicit save is needed — SwiftData auto-saves
- Use `FetchDescriptor(predicate:)` (not `filter:`) when constructing descriptors for imperative fetches
- After any `await` that follows a SwiftData model mutation, guard with `note.modelContext != nil` to handle deleted notes

### Platform-Specific Code
- Use conditional compilation for platform differences:
  ```swift
  #if canImport(UIKit)
      // iOS / iPadOS code
  #elseif canImport(AppKit)
      // macOS code
  #endif
  ```

### Style
- Declarative SwiftUI — avoid imperative patterns when a declarative equivalent exists
- Keep view bodies concise; extract reusable UI into subviews or helper methods
- Use trailing closure syntax for SwiftUI modifiers and view builders
- Use `if let` binding for optional unwrapping in view bodies
- Use `static` properties for shared formatters (e.g., `DateFormatter`)

## Data Model

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

    static let trashRetentionDays: Int = 30
}
```

- Title and content default to empty strings (not optional)
- `updatedAt` must be updated whenever the user modifies the note
- Notes are sorted by the user's chosen sort option (Last Modified / Created Date / Title) with pinned notes always first
- `deletedAt` is `nil` for active notes and set to the deletion date when moved to trash
- `isPinned` controls whether a note appears at the top of the list regardless of sort order
- `trashRetentionDays` (30) is the shared constant governing both purge logic and the UI countdown
- `NoteListView` queries only active notes: `@Query(filter: #Predicate { $0.deletedAt == nil })`
- On app launch, `ContentView` purges any notes trashed more than `trashRetentionDays` days ago using a predicate that includes the cutoff date

## Navigation & Selection

- `ContentView` holds `@State private var selectedNote: Note?` (direct model reference, no UUID lookup)
- `NoteListView` receives `@Binding var selectedNote: Note?` and uses `List(selection: $selectedNote)` with `NavigationLink(value: note)`
- When a note is moved to trash or deleted, `selectedNote` is explicitly set to `nil`
- `NoteListView` uses `.onChange(of: notes)` to clear `selectedNote` if it is no longer in the active notes array (e.g., deleted from another device via CloudKit)

## Apple Intelligence (AI)

The app integrates Apple Intelligence via `FoundationModels` (iOS 26 / macOS 26+). All AI code is gated behind `#if canImport(FoundationModels)` and `#available(iOS 26.0, macOS 26.0, *)` so the app remains fully functional on devices without Apple Intelligence.

- **`SimpleTextNotesAI`** — `@Observable` class injected via the environment from `ContentView` (not instantiated per-view):
  - `isAvailable: Bool` — static guard checked before rendering any AI UI
  - `makeSession(instructions:)` — creates a `LanguageModelSession`
  - `wrap(_:)` — normalizes errors into `SimpleTextNotesAIError` (`.modelUnavailable` / `.generationFailed`)
- **`TitleGenerationState`** — `@Observable` class injected via the environment; stores both in-progress IDs (for the animated dots indicator) **and** the `Task` objects (so tasks survive the view lifecycle). Use `startTask(_:for:showIndicator:)` / `markDone(_:)` / `cancelTask(for:)`.
- **AI button in `NoteDetailView`** — only rendered when `SimpleTextNotesAI.isAvailable`; uses `note.content` as the prompt; shows an informational alert if content is empty; appends generated output; shows an error alert on failure; registers an **undo operation** via `@Environment(\.undoManager)` before mutating content
- **Auto title generation** — triggered on `NoteDetailView.onDisappear` when the note title is empty; task is stored in `TitleGenerationState` (not in `@State`); a `guard note.modelContext != nil` check protects against race conditions after the async gap

### Conditional compilation pattern for FoundationModels

```swift
#if canImport(FoundationModels)
import FoundationModels
#endif

// ...

#if canImport(FoundationModels)
if #available(iOS 26.0, macOS 26.0, *) {
    // AI code
}
#endif
```

## Trash / Soft-Delete

Notes are soft-deleted by setting `deletedAt` rather than removed from the store immediately.

- **Move to trash** — sets `note.deletedAt = Date()`; the note disappears from `NoteListView` immediately
- **`TrashView`** — accessible via a toolbar button in `NoteListView`; lists trashed notes with a countdown of days remaining before permanent deletion; notes with `daysRemaining <= 0` show "Pending deletion" in red; swipe-left to **restore**, swipe-right to open a **confirmation alert** before permanently deleting; tap to read the note via `TrashedNoteDetailView` (read-only, inside the same `NavigationStack`); "Empty Trash" toolbar button purges all trashed notes after confirmation
- **Purge on launch** — `ContentView` calls `purgeOldTrashNotes()` at startup using a `FetchDescriptor` with a predicate that includes the cutoff date (only expired notes are fetched); errors are caught and logged
- **Delete confirmation** — the delete action in `NoteDetailView` shows a confirmation alert before moving the note to trash

## iCloud Sync Status

`CloudSyncMonitor` is an `@Observable` class defined in `ContentView.swift` and injected into the environment. It listens for `NSPersistentStoreRemoteChange` notifications (fired by SwiftData's CloudKit backend) and exposes `isSyncing: Bool`. `NoteListView` reads this from the environment and shows a `ProgressView` in the toolbar for 2 seconds after each remote change event.

## Pinning

Notes can be pinned via:
- Leading swipe action in `NoteListView` (pin / unpin with orange tint)
- Toolbar button in `NoteDetailView` (Cmd+Shift+P)

Pinned notes always appear at the top of the list regardless of the active sort option.

## Sorting

The active sort option is stored in `@AppStorage("noteSortOption")` and applied client-side in `NoteListView.displayedNotes`. Options:
- **Last Modified** (`updatedAt` descending) — default
- **Created Date** (`createdAt` descending)
- **Title** (ascending, locale-aware)

The sort is exposed as a `Menu` picker in the `NoteListView` toolbar.

## Undo Support

Programmatic content mutations (paste and AI generation) register undo operations via `@Environment(\.undoManager)` before mutating `note.content`. This makes them reversible with Cmd+Z on macOS or shake-to-undo on iOS. Native `TextEditor` typing undo is handled automatically by the system.

## Keyboard Shortcuts (macOS / Hardware Keyboard)

| Shortcut | Action |
|----------|--------|
| Cmd+N | New note |
| Cmd+Delete | Move current note to trash |
| Cmd+Shift+C | Copy note (title + content) |
| Cmd+Shift+V | Paste from clipboard (append) |
| Cmd+Shift+S | Share note |
| Cmd+Shift+P | Pin / Unpin note |

## Building and Testing

```bash
# Open in Xcode
open SimpleTextNotes.xcodeproj

# Build via command line
xcodebuild -scheme SimpleTextNotes -configuration Debug build

# Run tests via command line
xcodebuild -scheme SimpleTextNotes -configuration Debug test
```

Tests live in `SimpleTextNotesTests/SimpleTextNotesTests.swift` and use XCTest with an in-memory `ModelContainer`. All tests are in the `NoteTests` class.

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| SwiftData over Core Data | Modern, simpler API with built-in CloudKit sync support |
| `NavigationSplitView` | Single code path for iPhone (drawer), iPad (split view), and macOS (panels) |
| No external dependencies | Keeps the project lean and maintainable with only Apple frameworks |
| CloudKit via entitlements | Seamless iCloud sync without additional code |
| `@Bindable` for model editing | Direct two-way binding to persistent model properties |
| Soft-delete (trash) | 30-day retention window; notes are recoverable before permanent purge |
| `FoundationModels` for AI | Uses on-device Apple Intelligence; fully gated so the app works without it |
| `@Observable` for AI state | `SimpleTextNotesAI`, `TitleGenerationState`, and `CloudSyncMonitor` use `@Observable` (not `ObservableObject`) |
| `Note?` selection (not `UUID?`) | Direct model reference eliminates the need for a secondary `@Query` in ContentView to resolve the selection |
| `@ScaledMetric` for font sizes | Editor font sizes scale with the system Dynamic Type / Accessibility setting |
| `ShareLink` for sharing | Native system share sheet; no custom code needed |
| Client-side sort + filter | Simple and flexible; avoids needing multiple `@Query` instances for each sort direction |

## Localization

- 34 languages live in `SimpleTextNotes/*.lproj/Localizable.strings`, 69 keys each. `en` is the
  development language and the source of truth; every other file must carry the identical key set.
- The share extension has its own separate table under `ShareExtension/*.lproj`, 34 locales with
  11 `share_*` keys, resolved against the appex bundle. Keys do not cross between the two tables.
- Views pass the **key** straight to SwiftUI (`Text("untitled_note")`,
  `Label("copy_button", systemImage:)`), use `String(localized:)` when a `String` is needed
  imperatively, and `String(format: String(localized: "word_count_format"), …)` for formatted ones.
- Keys are `snake_case`, suffixed by role (`_button`, `_title`, `_message`, `_label`, `_prompt`,
  `_placeholder`, `_format`, `_navigation_title`).
- The 33 translation files share a key **order** that differs from `en` — follow the translations.
- Portuguese ships as `pt` (Brazilian wording, which Apple resolves a bare `pt` to) with
  `pt-PT` overriding it for European Portuguese. There is no `pt-BR` directory.
- `ar` and `he` are right-to-left. Shipping those `.lproj` directories is what makes iOS mirror
  the UI; the layout already mirrors cleanly because no view hardcodes a side.

## What to Avoid

- Do not use `CoreData` — the project uses SwiftData
- Do not add external package dependencies without a clear reason
- Do not use `UIKit` or `AppKit` types directly in shared view code — use conditional compilation
- Do not call `modelContext.save()` explicitly — SwiftData handles this automatically
- Do not use `ObservableObject` / `@ObservedObject` — use `@Bindable` with `@Model` or `@Observable` instead
- Do not instantiate `SimpleTextNotesAI` inside `NoteDetailView` — read it from `@Environment(SimpleTextNotesAI.self)`
- Do not call `LanguageModelSession` directly — route through `SimpleTextNotesAI` so availability checks are centralized
- Do not hard-delete notes in response to user "delete" actions — move them to trash by setting `deletedAt`; only `purgeOldTrashNotes()` and the permanent-delete action in `TrashView` should hard-delete
- Do not use `FetchDescriptor(filter:)` — SwiftData uses `FetchDescriptor(predicate:)`
- Do not store `Task` references for title generation in `@State` inside `NoteDetailView` — use `TitleGenerationState.startTask(_:for:showIndicator:)` so tasks survive the view lifecycle
- Do not use fixed numeric font sizes in the editor — use `effectiveFontSize` (derived from `@ScaledMetric` properties) so they scale with Dynamic Type
- Do not hardcode a user-facing English string in the main app or the share extension — add a
  localized key to all 34 `.strings` files of whichever table the code reads from
- Do not use `.left` / `.right`, `.offset(x:)`, or `semanticContentAttribute` in layout — they break RTL mirroring for `ar` and `he`; use `.leading` / `.trailing` and `.padding(.horizontal:)`
