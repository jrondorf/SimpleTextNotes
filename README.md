# Simple Text Notes

A simple plain text note-taking app built with SwiftUI for iOS, iPadOS, and macOS.

## Features

- **Master-Detail View** — Browse notes in a sidebar list with a detail editor pane.
- **Create Notes** — Tap the compose button to create a new note.
- **Edit Notes** — Title and content are saved automatically as you type.
- **Swipe to Delete** — Swipe a note in the list to delete it.
- **Delete from Detail** — Delete the current note using the toolbar trash button.
- **Copy & Paste** — Toolbar buttons to copy note text to clipboard or paste clipboard contents into the note.
- **Search** — Search notes by title or content using the built-in search bar.
- **Persistence** — Notes are stored using SwiftData with automatic iCloud sync via CloudKit.

## Requirements

- Xcode 15+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

## Project Structure

```
SimpleTextNotes/
├── SimpleTextNotes.xcodeproj/
├── SimpleTextNotes/
│   ├── SimpleTextNotesApp.swift     # App entry point
│   ├── ContentView.swift            # Main NavigationSplitView
│   ├── Models/
│   │   └── Note.swift               # Note data model
│   ├── Views/
│   │   ├── NoteListView.swift       # Master list view
│   │   └── NoteDetailView.swift     # Detail editor view
│   └── Assets.xcassets/
├── SimpleTextNotesTests/
│   └── SimpleTextNotesTests.swift   # Unit tests
└── README.md
```

## Getting Started

1. Open `SimpleTextNotes.xcodeproj` in Xcode.
2. Select a simulator or device target (iPhone, iPad, or My Mac).
3. Build and run (⌘R).
