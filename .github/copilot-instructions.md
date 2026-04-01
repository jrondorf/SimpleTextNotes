# GitHub Copilot Instructions — SimpleTextNotes

## Project Overview

**SimpleTextNotes** is a lightweight, cross-platform note-taking app for iOS, iPadOS, and macOS. It is built entirely with native Apple frameworks and has no external dependencies.

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
             ├─ NoteListView   — @Query, search/filter, swipe-to-delete
             └─ NoteDetailView — @Bindable, edit title/content, clipboard, delete
```

- `@Model` — marks `Note` as a SwiftData persistent class
- `@Query` — fetches and observes notes reactively in `NoteListView`
- `@Bindable` — enables two-way binding between `NoteDetailView` and a `Note` instance
- `@Binding` — passes state between parent and child views
- `onChange()` — triggers side effects like updating the `updatedAt` timestamp

## Project File Structure

```
SimpleTextNotes/
├── SimpleTextNotesApp.swift   # @main app entry point, ModelContainer setup
├── ContentView.swift          # NavigationSplitView, selected note state
├── Models/
│   └── Note.swift             # SwiftData @Model (id, title, content, createdAt, updatedAt)
├── Views/
│   ├── NoteListView.swift     # List with @Query, search, toolbar
│   └── NoteDetailView.swift   # Editor with toolbar, clipboard, delete
└── SimpleTextNotesTests/
    └── SimpleTextNotesTests.swift  # XCTest unit tests for Note model
```

## Coding Conventions

### Naming
- **Types** (structs, classes, enums): `PascalCase` — e.g., `NoteDetailView`, `NoteListView`
- **Variables and properties**: `camelCase` — e.g., `selectedNoteID`, `filteredNotes`, `updatedAt`
- **Private members**: marked with `private` keyword
- **File names**: match the primary type they contain, using `PascalCase`

### SwiftUI Patterns
- Use `@State` for local view state
- Use `@Binding` for state passed in from a parent
- Use `@Bindable` for two-way binding to a SwiftData `@Model` object
- Use `@Query` for fetching and observing SwiftData results
- Use `@Environment(\.modelContext)` to access the data context for insert/delete
- Prefer computed properties for derived values (e.g., `filteredNotes`)
- Use `.searchable()` modifier with a `searchText` state variable for search
- Use `ContentUnavailableView` for empty or unselected states

### SwiftData Patterns
- Define models with the `@Model` macro on a `class` (not `struct`)
- All model properties should have default values
- Access `ModelContext` via `@Environment(\.modelContext)`
- Use `modelContext.insert()` to add and `modelContext.delete()` to remove objects
- No explicit save is needed — SwiftData auto-saves

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
}
```

- Title and content default to empty strings (not optional)
- `updatedAt` must be updated whenever the user modifies the note
- Notes are sorted descending by `updatedAt` in `NoteListView`

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

## What to Avoid

- Do not use `CoreData` — the project uses SwiftData
- Do not add external package dependencies without a clear reason
- Do not use `UIKit` or `AppKit` types directly in shared view code — use conditional compilation
- Do not call `modelContext.save()` explicitly — SwiftData handles this automatically
- Do not use `ObservableObject` / `@ObservedObject` — use `@Bindable` with `@Model` instead
