# Version History

## 0.1.0 (build 1) — 2026-05-19

Initial release. Full Kanban task manager with local SwiftData storage.

### Board

- Horizontally scrollable Kanban with customizable groups. First-launch seed: Daily, Weekly, Waiting, Doing, Pending, Done.
- Editable project header — tap the title or subtitle to rename; tap the emoji icon to open a 40-emoji picker.
- Group header pill with colored dot, name, count, and `…` menu (Rename / Recolor / Delete).
- Cards show: optional doc icon (when notes exist), title, **multi-line tag chips that wrap and grow the card height**, working-date row, due-date row. Working/due dates render blue when upcoming, red when arrived or passed.
- Per-column **Top 10 + "More +N"** pagination — long groups don't render every card at once.
- **Pull-to-refresh** on each column resets pagination to 10 and re-renders.

### Tasks

- Create, edit, and delete via a card-style detail view with Title / Properties / Notes / Delete sections.
- Properties: Status (group picker), Tags (multi-select grid + inline "New" create), Working Date (single or range), Due Date, Reminder toggle.
- **Custom calendar picker** with date-range mode — start and end days fill solid; the days between form a tinted strip slightly shorter than the endpoint squares.
- Per-task local notifications via `UNUserNotificationCenter`, scheduled at 9 AM on the chosen date.

### Drag and drop

- Drag a card to reorder within its column or to another column to change status.
- Drag a group's header pill to reorder columns.
- Uses `.move` operation (no green `+` badge) and `.contentShape(.dragPreview, …)` to clip the lifted preview to the card / pill shape.

### Bottom navigation (Liquid Glass on iOS 26)

- `+` add button (left), search field (middle), settings gear (right), all in a `GlassEffectContainer` on iOS 26.
- Search field transforms when focused: `+` and gear slide out, `X` cancel slides in, board fades out, inline search results fade in (filters by title, notes, tag names, group names).
- Fallback `.thinMaterial` design on iOS 18–25.

### Settings

- **Appearance** — Theme (System/Light/Dark), Language (System/English/简体中文), Text Size (Small/Medium/Large via `DynamicTypeSize`), Group Width (Small 180 / Medium 200 / Large 220 pt), App Accent (9 colors with descriptors: Classic, Vivid, Rose, Fresh, Warm, Calm, Deep, Bold, Neutral), App Icon (6 alternates: Classic, Rose, Violet, Midnight, Neutral, Light).
- **Default** — **Card Order**: choose how cards sort within each group.
  - *Sort By* — Manual (drag to order), Title (alphabetical), Date (smart: working date → due date → title, with sensible nil fallbacks).
  - *Order* — Ascending / Descending (disabled when Sort By is Manual).
- **Customization** — Manage Groups (add / rename / recolor / drag-reorder / delete), Manage Tags (add / rename / recolor / delete).
- **Data** — iCloud Sync placeholder (Coming Soon), Manual Control sheet with Export Data, Import Data, Reset All Data.
- **About** — How to Use (7 numbered guide cards), Feedback (mailto: `zihengthedeveloper@gmail.com` with version/device prefill), Privacy, Disclaimer, Copyright, Version.

### Popups & confirmation

- Every popup sheet has both `Cancel` (top-leading) and `Done` (top-trailing) buttons; save-style sheets (Group Menu, Tag Edit, New Tag) use `Cancel` + `Save` / `Add` instead.
- All destructive actions go through `ConfirmationSheet` (icon tile + title + message + red Confirm / gray Cancel).
- Sheets support `[.medium, .large]` detents — drag the grab handle to expand.

### Data

- **Export** — JSON file with board, groups, tags, tasks (including dates, reminders, group/tag IDs, board emoji icon).
- **Import (merge by ID, then by name)** — records with matching IDs update in place; for groups and tags, a case-insensitive name match is the secondary lookup so seeded defaults collapse with imported ones. New records are inserted; records not in the file are preserved. Pending reminders for updated tasks are canceled and re-scheduled.
- **Reset All Data** — deletes everything and re-seeds the six default groups.
- Import and Export show a `ProgressOverlay` while running, then a native iOS alert ("Import Successful" / "Export Successful").

### Widget

- Upcoming Tasks home-screen widget (small / medium / large families), reads a JSON snapshot from the App Group `group.com.ijustin.task` written by the main app whenever data changes.

### Internals

- SwiftUI iOS 18+, Swift 5 language mode, Xcode 16 synchronized folder references.
- SwiftData with CloudKit-ready schema: every property defaulted, no `.unique` constraints, optional inverse relationships.
- Localization: `Localizable.xcstrings` for English + Simplified Chinese.
- Picker sheets all use `NavigationStack` + `[.medium, .large]` detents and a native toolbar (`Cancel` / `Done` or `Save`) so iOS 26 renders the buttons as Liquid Glass capsules.
- Custom `FlowLayout` (`Task/Components/FlowLayout.swift`) for wrapping tag chips. Reports the proposed width back from `sizeThatFits` to keep the row height consistent with placement and avoid overlap.
