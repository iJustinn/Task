# Lessons Learned

Practical knowledge accumulated while building Task — things to remember on the next pass.

## Project structure

### Xcode 16 synchronized folder references

The `task.xcodeproj/project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` for `Task`, `TaskWidgetExtension`, and `TaskTests`. This means:

- Any `.swift` you drop into `Task/Models/`, `Task/Views/…/`, etc. gets compiled into the target automatically — no manual file references to add.
- Subfolders work as expected. No need to "Add to target" dialogs.
- To exclude a single file from a particular target, use `PBXFileSystemSynchronizedBuildFileExceptionSet` with `membershipExceptions` listing relative paths.
- `Info.plist` belongs in `TaskWidgetExtension/` and is excluded from compilation via that exception set; it's referenced through `INFOPLIST_FILE` instead.

### SourceKit false-positives

When working with synchronized folders, SourceKit in the editor will frequently complain that types defined in sibling files are "not in scope." Examples seen:

- `Cannot find type 'BoardGroup' in scope`
- `Type 'SwiftDataError' has no member 'edit'` (where SourceKit confuses our `Mode.edit` enum case for a SwiftData error)
- `'main' attribute cannot be used in a module that contains top-level code`
- `No such module 'UIKit'`

**These resolve on `xcodebuild` compile.** Trust the actual build, not the editor red squiggles. The reason: SourceKit indexes files individually before reconciling the synchronized folder's target membership.

### Project identifiers

- App: `com.ijustin.task`
- Widget: `com.ijustin.task.WidgetExtension`
- Tests: `com.ijustin.task.Tests`
- App Group: `group.com.ijustin.task` (entitlement on both the app and the widget — needed for the widget snapshot)
- Asset Catalog: alternate app icons registered via build setting `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet Midnight Neutral Light"` plus `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`.

## SwiftData

### Naming collisions to avoid

Swift's standard library defines `Task` (concurrency) and `TaskGroup` (concurrency). SwiftUI defines `Group` (view) and `Tag` (as a `.tag()` modifier). Our domain types are therefore named:

- `Board`
- `BoardGroup` (not `TaskGroup` — collides with `Swift.TaskGroup<T>`)
- `TaskTag` (not `Tag` — collides with SwiftUI usage in pickers)
- `TaskItem` (not `Task` — collides with `Swift.Task` concurrency)

The first attempt used `TaskGroup` and SourceKit reported nonsensical "Value of type `TaskGroup<ChildTaskResult>` has no member `board`" errors. Renaming fixed it.

### CloudKit-ready schema

Even though iCloud sync isn't enabled today, the model is designed for it from day one. This means future migration is free:

- **Every property has a default value.** No `var foo: String` — always `var foo: String = ""`.
- **No `@Attribute(.unique)`.** CloudKit doesn't support unique constraints; uniqueness is enforced at the application level.
- **Optional inverse relationships.** Each to-one relationship (e.g. `TaskItem.board: Board?`) is optional. To-many relationships are non-optional arrays with `= []` defaults.
- **Relationships set with `inverse:`.** `@Relationship(deleteRule: .cascade, inverse: \BoardGroup.board) var groups: [BoardGroup]? = []` lets cascade deletes flow.

### Lightweight migration

Adding a new property with a default to an existing `@Model` triggers SwiftData's lightweight migration automatically. We did this for `Board.iconEmoji = "📌"` and no migration code was needed — existing boards picked up the default on next launch.

### Falling back to in-memory store

`SwiftDataManager.makeModelContainer()` falls back to an in-memory store if opening the persistent store fails. This keeps the app usable when SwiftData rejects a schema change during development. In production this almost never triggers; in tests the in-memory path is the primary one.

## iOS 26 specifics

### Liquid Glass

`BottomNavBar.swift` uses `#available(iOS 26.0, *)` to fork the implementation:

- iOS 26: `GlassEffectContainer { … .glassEffect(.regular.interactive(), in: Circle()) … }`
- iOS 18–25 fallback: `.thinMaterial` background with `secondarySystemBackground` circles

`.buttonStyle(.glass)` has its own opaque sizing that doesn't compose well with custom-sized children; we use `.glassEffect(.regular.interactive(), in: shape)` directly on a custom-frame button label for explicit height control (50 pt circles + 50 pt capsule for the search field).

### Native NavigationStack toolbar in sheets

After several rounds of building a custom `PickerSheetHeader` (cancel pill + centered title), we found the cleanest result was to just wrap each picker sheet in `NavigationStack { … }` with `.navigationTitle(…)` + `.navigationBarTitleDisplayMode(.inline)` and a `Button("Cancel") { dismiss() }` in `.topBarLeading`. iOS 26 renders these as Liquid Glass capsules automatically, sizes them consistently, and gives the title the right weight. **Don't reinvent the toolbar.**

### Drop operations and the green `+` badge

`.dropDestination(for: T.self)` defaults to `.copy`, which renders the green `+` overlay on the drag preview. To suppress it for move-style reordering:

```swift
.onDrop(of: [.utf8PlainText, .text, .plainText], delegate: someDropDelegate)
```

with a `DropDelegate` that returns `DropProposal(operation: .move)` from `dropUpdated(info:)`. The shared helper is `Task/Components/StringMoveDropDelegate.swift`. iOS then shows the move indicator (no `+`) when hovering over a valid target.

### Tightening the drag preview

`.contentShape(.dragPreview, shape)` (iOS 17+) on the source view clips the iOS-generated lifted preview to that shape, removing the rectangular gray "platter" backdrop. We use:

- `Capsule(style: .continuous)` for group header pills
- `RoundedRectangle(cornerRadius: 10, style: .continuous)` for task cards

The drag preview view inside `.draggable(_:preview:)` should be the bare visual (no extra shadow or padded background) — iOS adds the lift shadow itself.

## App Group and widget sharing

### Two separate Codable structs

The main app and the widget each define their own `UpcomingSnapshot` / `WidgetUpcomingSnapshot` Codable structs. They agree on field names (so the JSON round-trips), but neither imports the other's. This avoids a build-time dependency between the targets and keeps the widget extension lean. Tradeoff: drift risk — both have to be updated together if the snapshot shape changes.

### Simulator console noise

The iOS Simulator emits a flurry of system logs that look like errors but are not from our app:

- `Couldn't read values in CFPrefsPlistSource<…> for group.com.ijustin.task ... detaching from cfprefsd` — `cfprefsd` probing the App Group container before sandboxing finishes. Benign; appears in every simulator session for any App Group.
- `Received external candidate resultset` / `containerToPush is nil` / `Result accumulator timeout` — `CoreDuet` / `CoreSpotlight` indexing.
- `The variant selector cell index number could not be found.` — CoreText complaining about emoji variation selectors. The glyph still renders.
- `CoreData: debug: WAL checkpoint` — SwiftData (CoreData) flushing its write-ahead log. Healthy.

None of these appear on a real device. Filter the Xcode console with `Task[` to see only our app's output, or set `OS_ACTIVITY_MODE=disable` as a Debug-only environment variable to silence most of it.

## SwiftUI patterns

### Settings card UI

Coin/Body's card-section visual language is in `Task/Components/`:

- `taskCardBackground(cornerRadius:)` — adaptive system background fill, soft shadow on light mode, hairline border.
- `SettingsCardSection("Title") { content }` — section title above (`.system(size: 29, weight: .bold, design: .rounded)`) and a rounded card containing the rows.
- `SettingsRowLabel(title:value:systemName:tintColor:accessory:)` — 44 pt colored-bg icon tile + rounded headline title + rounded headline value + chevron, 70 pt min height, 18/14 padding.
- `SettingsRowDivider()` — `Divider().padding(.leading, 76)` so it lines up under the row text.
- `SettingsButtonRow(title:systemName:tintColor:action:) { trailing }` — tappable variant.

Using these consistently across Settings, Manage Groups, Manage Tags, Task Detail, and the various sheets is what makes the app feel coherent.

### Card style for detail forms

`TaskDetailView` is built from four `taskCardBackground()` cards (title input / properties / notes / delete) on a `Color(.systemGroupedBackground)` background. **Don't use `Form` for the task detail** — `Form`'s built-in styling fights the card visual the rest of the app uses.

### Picker tiles

`GridTile` in `Task/Components/GridTile.swift` is the shared tile used by every grid picker. It handles three variants:

- **`imageAsset`** present → render the image at 96×96, clipped to a 22 pt rounded rectangle (used for App Icon picker). No tinted background — the icon has its own.
- **`systemImage`** present → SF Symbol at 28 pt in a 60×60 tinted square (used for Theme / Accent / Text Size / Status / Tags / etc.).
- **`dotColor`** present → solid color circle in a 60×60 tinted square (used for Status when each group is a color).

Selected state shows a checkmark badge in the top-right and a tinted card border.

### FlowLayout sizing pitfall

`Task/Components/FlowLayout.swift` is a custom `Layout` that lays out subviews left-to-right and wraps to the next line when the proposed width is exceeded — used for tag chips on `TaskCardView`.

There's one subtle trap: **`sizeThatFits` must report a width equal to the proposed width** when one is given, not the natural width of the longest line. If you report `(content_width, total_height)` and `content_width < proposal.width`, the parent VStack will allocate only `content_width` of horizontal space for the layout. Then `placeSubviews(in: bounds, …)` is called with `bounds.width = content_width`, and `arrange` re-wraps the chips at that narrower width — overflowing past the height SwiftUI just reserved.

Fix: return `(proposal.width, wrapped_height_at_proposal_width)` so `sizeThatFits` and `placeSubviews` see the same width.

```swift
let arrangement = arrange(subviews: subviews, maxWidth: maxWidth)
let reportedWidth = (proposal.width).flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? arrangement.size.width
return CGSize(width: reportedWidth, height: arrangement.size.height)
```

When `proposal.width` is `nil` / non-finite, fall back to `maxWidth = 0` (which forces one subview per row, giving the worst-case height) so the parent reserves enough vertical space regardless.

#### Three follow-up rules to keep measurement and placement in lock-step

The "report `proposal.width`" rule is necessary but not sufficient. Three more things have to agree, or chips silently overlap the next row in the card:

1. **`placeSubviews` must use `proposal.width`, not `bounds.width`.** They are usually equal, but SwiftUI is free to hand you a narrower `bounds` during placement (and the layout dance can call `sizeThatFits` with several proposals, only one of which becomes the bound). Anchor the wrap math to `proposal.width` with `bounds.width` as a fallback, so placement re-runs the exact arrangement `sizeThatFits` reserved height for.

2. **Probe each subview with `ProposedViewSize(width: .infinity, height: .infinity)`, not `.unspecified`.** `.unspecified` lets the subview's `Text` decide for itself, and at certain dynamic-type sizes it returns a slightly *narrower* size than what actually renders. The wrap check then says "fits" while the real chip pushes onto the next line — exactly the Print-bank-statement overlap. The infinite proposal forces the unwrapped, single-line natural size that matches what `.fixedSize()` will render.

3. **Pin tag chips with `.lineLimit(1).fixedSize(horizontal: true, vertical: false)`.** Without it, a `Text` chip can be squeezed by `place(proposal:)` and re-wrap itself, again diverging from the FlowLayout's measurement. With it, every measurement and every placement agree on the chip's width down to the pixel.

The symptom of breaking any one of these: a card with two short tags wraps "Exam" alone onto row 1 and "Finance" onto row 2, but the row-2 chip lands on top of the working-date row because `FlowLayout` only reserved one row's worth of height. Always reproducible at larger Dynamic Type sizes where rendered glyph widths drift further from `.unspecified`'s reported width.

### Card pagination

`ColumnView` caps each column at the first 10 tasks via `@State private var visibleCount: Int = 10`. When the group's `currentTasks.count > visibleCount`, a tinted "More +N" button appears at the bottom of the column and bumps the count by 10 (animated). The state is preserved across re-renders thanks to `ForEach`'s id-keyed identity, but reset to 10 on pull-to-refresh.

### Pull-to-refresh as a recovery valve

Each column's inner `ScrollView` has `.refreshable { …  visibleCount = 10 }`. Even when the live data should already be in sync, this is a free "fix anything stuck" gesture for users — when a sort change doesn't seem to apply, when the column shows fewer cards than expected, etc. Bonus: SwiftUI's standard spinner is familiar and self-explanatory.

### Calendar picker

`CalendarPicker.swift` supports two modes via an enum:

- `.single(Binding<Date?>)` — tap to set, tap again to clear.
- `.range(Binding<Date?>, Binding<Date?>)` — tap once for start, again later for end. After both set, tapping resets to a new single-day selection.

Visual:
- Endpoint cells (start / end / single) get a 38 pt filled rounded square.
- "Between" cells get only the tinted strip background (no endpoint).
- The strip is constrained to `height: 34` so it reads as **slightly shorter** than the 38 pt endpoint squares (matches the iOS Calendar app aesthetic).
- Grid `columns` use `spacing: 0` horizontally so the strip is continuous across cells in a row; row spacing is `4` vertically.

### Confirmation sheets

`ConfirmationSheet(icon:iconTint:title:message:confirmLabel:onConfirm:)` in `Task/Components/` replaces `confirmationDialog`. Reasons:

- Matches the Coin/Body visual language (rounded tinted icon tile, large bold title, secondary message, red filled button, gray cancel button).
- Drag-to-dismiss with a `.height(420)` detent.
- The "delay then run" pattern (`dismiss()` + `Task.sleep(180_000_000)` + `onConfirm()`) ensures the sheet animates away before the action fires, which prevents flicker if the action triggers another sheet/alert.

Used everywhere destructive: Delete Task, Delete Group, Delete Tag, Reset All Data.

### Progress overlay

`ProgressOverlay(title:message:progress:)` is the dimmed full-screen overlay shown during Import / Export. `progress: nil` shows a spinner; passing a `Double` shows a linear bar. Wrap the screen in a `ZStack` and toggle the overlay with `if isImporting { … }` + `.animation(.easeInOut(duration: 0.18), value: isImporting)`.

## Settings propagation

### Force re-render with `.id()` when a non-data setting changes the layout

The Card Order setting changes how `BoardGroup.sortedTasks(field:direction:)` orders the same task array. `@EnvironmentObject` in `ColumnView` does trigger a body recompute when settings change, but `LazyVStack` aggressively reuses cells by ID, so visually the column might keep stale ordering. Adding

```swift
.id("\(settings.cardSortField.rawValue)-\(settings.cardSortDirection.rawValue)")
```

on the `LazyVStack` forces SwiftUI to rebuild the column from scratch when the sort settings change. The cost is a single rebuild on setting change; the benefit is correctness with no surprises.

### `@EnvironmentObject` with a `@Published`-driven view model

`SettingsViewModel` exposes every setting as `@Published var foo: SomeEnum { didSet { UserDefaults.set(...) } }`. This pattern combines reactivity (any view observing the env object re-renders on change) with synchronous persistence (every change writes immediately to `UserDefaults`). No save button needed for picker sheets — selection is the save.

### Sort field migration

When `CardSortField` was collapsed from four cases (`manual`, `title`, `workingDate`, `dueDate`) to three (`manual`, `title`, `date`), existing users had `"workingDate"` or `"dueDate"` strings stored. The init handles this manually rather than letting the unrecognized values fall back to `.manual`:

```swift
let raw = d.string(forKey: …) ?? ""
if raw == "workingDate" || raw == "dueDate" {
    self.cardSortField = .date
} else {
    self.cardSortField = CardSortField(rawValue: raw) ?? .manual
}
```

Whenever enum cases are removed or merged, surface the migration explicitly. The default-fallback path silently downgrades user preferences.

## Data import / export

### Merge by ID first, then by name

`DataImportExport.importData(_:context:)` matches imported entities to existing ones in this order:

1. **ID match** — same UUID → update in place.
2. **Name match** (groups and tags only, case-insensitive) — same name → update the existing record and remap the imported UUID to the existing object in the lookup dictionary so tasks in the same payload that reference the imported UUID resolve to the existing group/tag.
3. **Insert** — neither match → create a new entity with the imported UUID.

The name-based fallback is critical because on every fresh install, `SwiftDataManager.ensureSeed` creates the six default groups with **freshly-minted UUIDs**. Without a name match, importing a previously-exported board on a different device (or after Reset All Data) would create duplicate groups: original "Daily" with seed UUID + imported "Daily" with the export's UUID. The fallback collapses them.

Tasks are still ID-only (no name fallback) since task names aren't unique and duplicates are a legitimate case.

### Date integrity in test data

When generating test data externally, due dates must be ≥ working dates (or working-end if a range). Otherwise the import is technically valid but logically broken, and the user has to either manually fix or re-export real data to learn what "good" looks like. A quick post-processing pass fixes this without re-generating from scratch.

### Merge by ID, not wipe

`DataImportExport.importData(_:context:)` is non-destructive — entities not present in the imported file stay put. **Never wipe existing data on import** unless that's the explicit user gesture (Reset All Data).

For the single board: if no ID matches but a board exists, reuse the existing board (preserving its ID) and overwrite its metadata. This avoids creating a duplicate board.

### Notification re-scheduling on import

When a task is updated via import, cancel its old pending notification first (`NotificationService.cancel(for: existing)`), then re-schedule based on the updated `hasReminder` value. Don't assume the old notification still matches the new dates.

### File round-trip

JSON uses `JSONEncoder().dateEncodingStrategy = .iso8601` and `.outputFormatting = [.prettyPrinted, .sortedKeys]`. The decoder uses `.iso8601` too. UUIDs serialize as uppercase via `UUID.uuidString`. When generating test data externally (Python, etc.), use `.upper()` on UUIDs and `"%Y-%m-%dT%H:%M:%SZ"` for dates to match.

### FileDocument minimum

`TaskExportDocument` is a tiny `FileDocument` holding `Data`. `.fileExporter` writes it; `.fileImporter` returns a URL whose contents we load and decode. Both UTType is `.json`.

## Notifications

### Default reminder time

When a task's reminder date has no time component (which it never does for date-only fields), default to 9 AM:

```swift
if components.hour == 0 && components.minute == 0 {
    components.hour = 9
}
```

`UNCalendarNotificationTrigger(dateMatching: components, repeats: false)`. The reminder identifier is `task.id.uuidString` so we can cancel cleanly.

## Drag and drop UX

### Disambiguating task vs group drops

Both tasks and groups are dragged through the same `.onDrop(of: [.text], …)` listener on `ColumnView`. To tell them apart, group drags are encoded as `"group:<uuid>"` while task drags are the bare UUID string. `handleDrop(raw:fallbackIndex:)` peels the prefix and routes to the right reorder callback.

### Don't fight the column's existing background

Each column already has a tinted card background and a `dropDestination` (now `onDrop`) on the whole column. The per-task drop targets handle reorder-within-column; the column-wide drop target handles cross-column moves. They share the same delegate, the same drop-handling function — just different fallback indices.

## Localization

`Localizable.xcstrings` covers English and Simplified Chinese. New strings added via `String(localized: "…")` or plain `Text("…")` get auto-extracted on build thanks to `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`. Don't manually edit the JSON unless adding translations.

## Things to do later

- **iCloud sync** — enable `cloudKitDatabase: .private` on `ModelConfiguration` and add the CloudKit entitlement. Schema is already compatible.
- **Multi-board** — the data model is board-scoped from day one, so swapping `RootView`'s single-board lookup for a board picker is a UI change only.
- **Custom group icons / tag icons** — currently colored dots / tag glyphs. Could add a per-group emoji like the board's.
- **Reminder time** — currently defaults to 9 AM. Could expose a time picker per task.
- **Widget interactivity** — tapping the widget could deep-link to the relevant task via App Intents.
- **Watch app** — board snapshot via the same App Group JSON would make a Watch complication trivial.
