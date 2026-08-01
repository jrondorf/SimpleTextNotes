# TODO — SimpleTextNotes

Findings from a full read of the codebase at `d2e2e92` (v1.7). Ordered by priority.

**Verification status:** this review was done on Linux with no Swift toolchain, so nothing was
compiled or run. Items marked **[verified]** were confirmed by direct inspection (file
contents, key diffs, `project.pbxproj` settings). Items marked **[needs Xcode]** are reasoned
from the source and must be confirmed on a Mac before acting.

---

## P1 — Correctness bugs

- [ ] **Three iCloud accessibility labels are missing from every locale** — **[verified]**
  `Views/NoteListView.swift:180,184,188` reference `icloud_synced_label`, `icloud_error_label`,
  and `icloud_label`, but only `icloud_syncing_label` exists (`en.lproj/Localizable.strings:179`).
  A `grep -l` across all 23 `.lproj` files returns **0** matches for the other three.
  VoiceOver currently announces the raw key names ("icloud_synced_label") in every language.
  *Fix:* add the three keys with translations to all 23 `Localizable.strings` files.

- [ ] **Test target uses `FetchDescriptor(filter:)`, which is not a valid initializer label**
  — **[needs Xcode]** `SimpleTextNotesTests/SimpleTextNotesTests.swift:87,93,114`.
  `FetchDescriptor` takes `init(predicate:sortBy:)`; `filter:` is the `@Query` label. App code
  correctly uses `predicate:` (`ContentView.swift:73,98`). If this is what it looks like, the
  test target does not compile and has not for some time — there is no CI to catch it.
  *Fix:* rename to `predicate:`, then actually run the suite.

- [ ] **Share extension can duplicate the shared text** — **[needs Xcode]**
  `ShareExtension/ShareViewController.swift:268-289`. The loop appends each attachment
  conforming to `plainText`/`url`, and *then* separately appends
  `item.attributedContentText?.string`. For many share sources those are the same text, so the
  note gets it twice. *Fix:* only fall back to `attributedContentText` when no attachment
  produced content.

- [ ] **Shared-note handoff can lose content** — **[verified]**
  `ContentView.swift:88-92` reads `pendingSharedNotes` and immediately removes the key before
  inserting any notes; a crash or early `continue` between the two loses the payload. The
  read-modify-write in `ShareViewController.saveNote` (`:339-353`) is also unsynchronized
  against the app's drain, so a share arriving during foregrounding can be dropped.
  *Fix:* delete each entry only after its note is inserted, and coordinate access (file
  coordination or an atomic swap) instead of `removeObject` + iterate.

## P2 — Build, signing, and release configuration

- [ ] **Debug builds have no `aps-environment` entitlement** — **[verified]**
  `SimpleTextNotesRelease.entitlements` declares `aps-environment = production`, but
  `SimpleTextNotes.entitlements` (used by the Debug configuration) declares none, while
  `Info.plist` requests the `remote-notification` background mode. CloudKit's silent push
  notifications will not be delivered to Debug builds, so sync only reconciles on launch or
  foreground during development. *Fix:* add `aps-environment = development` to the Debug
  entitlements.

- [ ] **Two divergent entitlements files are easy to desync** — **[verified]**
  The Debug/Release split exists only for that one key. Consider a single entitlements file
  (Xcode manages `aps-environment` per-configuration automatically), or add a check that the
  two files differ only in expected ways.

- [ ] **`CURRENT_PROJECT_VERSION = 1` on every target/configuration** — **[verified]**
  The build number has never been incremented while `MARKETING_VERSION` reached 1.7. Every
  App Store upload needs a unique build number. *Fix:* bump per upload, or derive it
  (e.g. from the git commit count) in a build phase.

- [ ] **`scripts/generate_icons.sh` writes to the wrong project** — **[verified]**
  `scripts/generate_icons.sh:7` targets `${REPO_ROOT}/HoroDrift/Assets.xcassets/AppIcon.appiconset`
  — a leftover from a different app. Running it creates a stray `HoroDrift/` directory and
  never updates this app's icons. *Fix:* point it at `SimpleTextNotes/Assets.xcassets/…`.

- [ ] **Dark and tinted app icons are byte-identical copies of the light icon** — **[verified]**
  `AppIcon-1024.png`, `AppIcon-1024-dark.png`, and `AppIcon-1024-tinted.png` all hash to
  `6013f7eb…`, because `generate_icons.sh:36-37` simply `cp`s them. `Contents.json` declares
  them as real dark/tinted appearance variants, so iOS 18+ shows an unadapted icon in dark and
  tinted modes. *Fix:* author genuine variants (tinted should be a grayscale/monochrome mask).

## P3 — Performance and data flow

- [ ] **`updatedAt` is rewritten on every keystroke** — **[verified]**
  `NoteDetailView.swift:88-89` sets `note.updatedAt = Date()` in `onChange` of both title and
  content. With the default "Last Modified" sort this re-sorts the sidebar while the user
  types, and it amplifies CloudKit writes. *Fix:* debounce (e.g. a `Task` cancelled per
  keystroke, committing after a pause) or set `updatedAt` on editor dismissal.

- [ ] **`syncNotesList()` rewrites the full note list to shared `UserDefaults` on every change**
  — **[verified]** `ContentView.swift:57-59` calls it from `onChange(of: notes)`, which fires
  on each edit, serializing every note's id/title/date. *Fix:* debounce, and write only when
  the titles actually changed.

- [ ] **Share picker's note list is unbounded and unordered** — **[verified]**
  `syncNotesList` (`ContentView.swift:120-129`) emits every active note in `@Query` order, and
  `loadNotesList` (`ShareViewController.swift:325-334`) consumes it as-is. With hundreds of
  notes the picker becomes unusable. *Fix:* sort by `updatedAt` descending and cap the export
  (e.g. 50 most recent), ideally with search in the picker.

- [ ] **Append-by-id fetches every active note and scans in memory** — **[verified]**
  `ContentView.swift:97-103` builds a `FetchDescriptor` for all non-trashed notes then does
  `first(where: { $0.id == uuid })`. *Fix:* put the id in the predicate.

- [ ] **Trash purge fetches all trashed notes and filters in Swift** — **[verified]**
  `ContentView.swift:70-86`. Acceptable at current scale, but the cutoff belongs in the
  predicate if it can be expressed against the CloudKit-backed store. Purge also runs only in
  `.task` at launch, so a long-running session shows "Pending deletion" rows indefinitely
  (`TrashView.swift:84-89`). *Fix:* also purge on foreground.

## P4 — Duplication and structure

- [ ] **AI title generation is duplicated almost verbatim** — **[verified]**
  `ContentView.generateAutoTitle` (`:141-166`) and `NoteDetailView.generateTitle` (`:239-264`)
  share the same prompt string and the same `maxTitleLength` / `maxContentLengthForTitleGeneration`
  constants, declared separately in both files. They will drift. *Fix:* move the prompt,
  constants, and the whole routine into `SimpleTextNotesAI`.

- [ ] **`displayedNotes` filter/sort logic is untestable** — **[verified]**
  `NoteListView.swift:42-56` holds the search + pin + sort rules inside the view. *Fix:*
  extract to a free function or small type so the sorting rules can be unit-tested.

- [ ] **Duplicate static `DateFormatter`** — **[verified]**
  Identical instances in `NoteListView.swift:58-63` and `TrashView.swift:40-45`. Also, a cached
  `DateFormatter` does not pick up a locale change at runtime. *Fix:* share one helper, or use
  `Date.formatted(date:time:)`.

- [ ] **`effectiveFontSize` matches `Double`s by equality** — **[verified]**
  `NoteDetailView.swift:27-40` declares four `@ScaledMetric` properties and selects between
  them with `case 14.0:` / `case 18.0:` etc. Any new size, or a value written by the
  Settings.bundle that doesn't match exactly, silently falls back to medium. *Fix:* scale a
  single base value (e.g. `UIFontMetrics`/`ScaledMetric` on one property) instead of switching.

- [ ] **`CloudKitSyncMonitor` never returns to idle** — **[verified]**
  `CloudKitSyncMonitor.swift:56-62` sets `.synced` and leaves it; the checkmark stays in the
  toolbar for the rest of the session. *Fix:* revert to `.notSyncing` after a delay.

## P5 — Localization and accessibility

- [ ] **The share extension is entirely unlocalized** — **[verified]**
  13 hardcoded English strings in `ShareExtension/ShareViewController.swift` ("Save",
  "New Note", "SAVE TO", "Add text to note...", "Existing Notes", "Untitled", "Done", the two
  destination subtitles, …). The app ships 23 languages; the share sheet is English for all of
  them. *Fix:* add `Localizable.strings` to the extension target and localize.

- [ ] **No `.stringsdict` for plurals** — **[verified]**
  `days_until_deletion_format` is `"%d day(s) until permanent deletion"` and the German is
  `"%d Tag(e) …"` — the `(s)`/`(e)` workaround exists precisely because plurals aren't
  handled. `word_count_format` has the same issue. Slavic locales (cs, pl, ru, uk) need three
  plural forms. *Fix:* add `Localizable.stringsdict` per locale for these two keys.

- [ ] **`Settings.bundle/Root.plist` is English-only** — **[verified]**
  It declares `StringsTable = Root` but no `Root.strings` exists in any `.lproj`, so the iOS
  Settings pane shows "Editor Font"/"Font Style"/"Small (14)" in English everywhere. *Fix:*
  add `Root.strings` per locale, or drop the Settings bundle in favor of the in-app sheet.

- [ ] **Editor and generating-title indicator lack accessibility labels** — **[verified]**
  The `TextEditor` (`NoteDetailView.swift:65`) has no label, and `GeneratingTitleView`
  (`NoteListView.swift:4-16`) animates dots that VoiceOver reads as punctuation. *Fix:* add
  `.accessibilityLabel` to both.

- [ ] **Empty-titled notes sort first under "Title" sort** — **[verified]**
  `NoteListView.swift:53` compares `a.title` directly, so notes displayed as "Untitled" sort
  as `""` and cluster at the top. *Fix:* sort on the displayed string.

- [ ] **Inconsistent delete confirmation** — **[verified]**
  `NoteDetailView` confirms before trashing (`:176-186`), but swipe-to-delete in the list
  (`NoteListView.swift:100-110`) trashes immediately with no undo affordance. *Fix:* pick one
  behavior; a toast with Undo is the usual answer for a recoverable soft-delete.

## P6 — Testing and CI

- [ ] **No CI at all** — **[verified]** `.github/` contains only `copilot-instructions.md`.
  A macOS Actions workflow running `xcodebuild build` + `test` on PRs would have caught the
  `FetchDescriptor(filter:)` item above. *Fix:* add `.github/workflows/ci.yml`.

- [ ] **Test coverage is limited to the `Note` model** — **[verified]**
  8 tests, all on construction/persistence/trash-state round-trips. Untested: search + sort +
  pin ordering, the 30-day retention boundary, the share-extension payload contract
  (`notesList` / `pendingSharedNotes` shapes), `SimpleTextNotesAI.wrap`, and
  `TitleGenerationState` task lifecycle. *Fix:* add tests as the logic gets extracted (see P4).

- [ ] **No lint/format tooling** — **[verified]** No SwiftLint or swift-format config.
  *Fix:* add one and wire it into CI, or explicitly decide against it.

- [ ] **No SwiftUI previews** — **[verified]** No `#Preview` anywhere, so every UI tweak needs
  a full build+run. *Fix:* add previews backed by an in-memory `ModelContainer`.

## P7 — Repository housekeeping

- [ ] **`.gitignore` covers only `.DS_Store`** — **[verified]**
  `xcuserdata/…/UserInterfaceState.xcuserstate` (~100 KB binary) is tracked and changes on
  every Xcode session; `d2e2e92` is a real commit whose diff is mostly that file. *Fix:* add
  `xcuserdata/`, `build/`, `DerivedData/`, `*.xcuserstate`, and `git rm --cached` the tracked
  ones.

- [ ] **`README.md` is stale** — **[verified]** Its feature list, project tree, and
  "iOS 17.0+ / macOS 14.0+ / Xcode 15+" requirements predate trash, AI, settings,
  localization, and the share extension; the app target is now iOS 26.0 and Mac support is
  Catalyst. *Fix:* regenerate from the current state.

- [ ] **`.github/copilot-instructions.md` has drifted from the code** — **[verified]**
  It describes an inline `CloudSyncMonitor` with `isSyncing` (now `CloudKitSyncMonitor.swift`
  with a four-state enum), a purge predicate that includes the cutoff (now an in-memory
  filter), and `deletedAt`-based queries (now `isTrashed`). *Fix:* update it alongside
  `CLAUDE.md`, or have one file include the other.

- [ ] **Only the `ShareExtension` scheme is shared** — **[verified]**
  `xcshareddata/xcschemes/` lacks `SimpleTextNotes.xcscheme`, so a fresh clone can't
  `xcodebuild -scheme SimpleTextNotes` until Xcode autocreates it — and CI would need it.
  *Fix:* mark the app scheme shared and commit it.

## P8 — Feature ideas (not defects)

- [ ] Export / import notes (single note or bulk, `.txt` / `.md`).
- [ ] Share extension support for images and files, not just text and URLs.
- [ ] Search inside the share picker's note list.
- [ ] Undo toast after swipe-to-trash in the list.
- [ ] Additional AI actions (summarize, rewrite, extract to-dos) built on the existing
      `SimpleTextNotesAI` session wrapper.
- [ ] Recovery affordance in `DatabaseErrorView` (`SimpleTextNotesApp.swift:33-52`) — it
      currently shows the raw error with no retry or reset path.
- [ ] Widgets / Shortcuts (App Intents) for quick capture.
