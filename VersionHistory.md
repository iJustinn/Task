# Version History

## 0.4.0 (build 1) — 2026-05-21

Multi-board support across the app, the settings, and the home-screen widget.

### Multi-board

- **Three default boards seed on fresh install** — Personal 🏃, Study 🎓, Work 💼 — each with the standard five default groups (Waiting, Doing, Pending, Done, Archive) and no preset tags. Existing single-board installs upgrade in place; no migration code needed for the new defaulted `Board` fields.
- **Default seed groups slimmed down** — removed Daily and Weekly, added Archive. New order: Waiting, Doing, Pending, Done, Archive. Tests updated.
- **Board switcher** — folder button on the bottom nav between Search and Settings opens a 60% sheet with a 3-column grid of board tiles (icon + title + task count, via the shared `GridTile`). Drag indicator + pullable to large.
- **Long-press drag-reorder boards** — same `.draggable` + per-tile `DropDelegate` pattern as Groups / Tags / Columns. Reorder persists via the new `Board.sortIndex`.
- **Drag-to-delete with confirmation** — while reordering, a red trash bar slides up from the bottom edge. Dropping a tile onto it opens the existing `ConfirmationSheet` (`Delete Board?` / red Delete Board / gray Cancel). Disabled when only one board remains. Active board auto-falls-back to the next-remaining board on delete.
- **In-place board create** — tap **Add** in the switcher; a new board lands as the active one with placeholder text ("Choose a Title" / "Choose a Subtitle"). Edit title/subtitle/icon directly in the board header (`ProjectHeaderView`), which now also re-syncs its draft strings when the active board changes via `onChange(of: board.id)`.

### Settings rewired per-board

- **Default → Status / Card Order / Reminder Time** moved from `SettingsViewModel` global UserDefaults into per-board fields on the `Board` model (`defaultGroupID`, `cardSortFieldRaw`, `cardSortDirectionRaw`, `reminderMinutesOfDay`). Each board remembers its own. `DefaultStatusPickerSheet`, `CardOrderPickerSheet`, and `ReminderTimePickerSheet` now take a `Board` and write to it directly.
- **Customization → Groups / Tags** already scoped to a board via SwiftData relationships; switching boards swaps which board they manage.
- **One-shot legacy migration** — on first launch after upgrade, copies the four legacy `UserDefaults` keys onto the first board (by `createdAt`) so 0.3.x users keep their preferences. Guarded by `task.boardDefaultsMigrated` so it never re-runs.

### Notifications

- `NotificationService.schedule(for:)` reads `task.board?.reminderMinutesOfDay` instead of the deleted global UserDefaults key, falling back to 9 AM when the board reference is nil.

### Multi-board import / export

- **New wire format**: `MultiBoardExportPayload { version: 2, exportedAt, boards: [BoardExportEntry] }`. Each `BoardExport` carries its per-board prefs.
- **Legacy v1 single-board exports** still decode — wrapped into a one-entry `boards` array.
- **Reset All Data** wipes every board, clears the active-board UserDefaults key, then re-seeds the three defaults.
- **Board match is ID-only** for imports (no "reuse first existing board" fallback that 0.3.x had). Group/tag merge is ID → same-board-name → insert, scoped to each board.

### Widget — per-widget board configuration

- Converted `UpcomingTasksWidget` from `StaticConfiguration` to `AppIntentConfiguration` with a new `BoardConfigurationIntent` (`@Parameter var board: BoardEntity?`, where nil = All Boards).
- `BoardEntity` + `BoardEntityQuery` populate the widget edit picker by reading a new `BoardListEntry[]` written to the App Group every time the upcoming snapshot is rewritten.
- `UpcomingSnapshotEntry` and the widget's `WidgetUpcomingEntry` gained `boardID`, `boardEmoji`, `boardTitle`. The widget UI shows the board emoji on each row when "All Boards" is configured; the header shows the chosen board's emoji + title when a specific board is selected.
- Snapshot is rewritten on board create / rename / icon change / delete in addition to the existing task-change triggers.

### Bottom nav

- New **folder** circle button (`folder.fill`) between the search field and the gear, opens the board switcher.
- Long-press on the `+` button (which previously was a route to create a board) was removed — board creation goes through the switcher's **Add** button.

### Testdata

- `TestData/testdata.json` regenerated for the three default boards (125 tasks each) with realistic date distribution (overdue / today / this week / later this month) and notes/reminder/tag mixes. Preserves board / group / tag IDs so re-imports update in place.

## 0.3.0 (build 2) — 2026-05-20

Notion-style task editor redesign and global toolbar/calendar polish.

### Task detail screen — Notion-style flat redesign

- **Replaced the four-card layout** (title / properties / notes / delete) with a single flat surface on `Color(.systemBackground)`. No more `taskCardBackground()` wrappers in the editor.
- **Title** is now a large bold `TextField` (`.largeTitle`, rounded) sitting directly on the surface — no card.
- **Properties** rewritten as compact rows: 16 pt secondary-gray SF Symbol + 120 pt label column + value. 42 pt min height (down from 64–70 pt). Five rows: Status, Tags, Working, Due Date, Reminder.
- **Pastel pill values** for Status (group capsule with dot + name) and Tags (reuses `TagChip`); "Empty" gray placeholder when unset.
- **Date tinting** in the editor mirrors `TaskCardView`: working/due dates render blue when `startOfDay(date) > today`, red when today or past.
- **Reminder anchor**: when `hasReminder` is on, the alarm icon (`alarm` SF Symbol) appears on whichever row matches `TaskItem.primaryReminderDate` — i.e., the earlier of `workingStart` and `dueDate`. A new `reminderAnchor` computed prop in `TaskDetailView` mirrors that logic so the badge can never drift from where the notification actually fires.
- **Working date range** wraps onto two explicit lines (`May 19, 2026 →\n May 22, 2026`) inside the editor. A private `workingDateDisplay(start:end:)` injects the `\n` so the shared `TaskDateFormat.formatRange` and the board card behavior are unaffected.
- **Alarm icon** sits at the trailing edge of its row (pushed by `Spacer(minLength: 8)`) and vertically centers against the multi-line date text via `HStack(alignment: .center)`.
- **Toggle rows** (Reminder, End Date) right-align their `Toggle` via a new `valueAlignment:` parameter on `propertyRow`. Text values still left-align at the 120 pt column.
- **Delete moved out of the toolbar** and onto a flat full-width red button at the very bottom of the scroll content. Pinned to bottom when notes are short; flows naturally below the notes when they grow. Uses `GeometryReader` + `.frame(minHeight: proxy.size.height)` on the inner `VStack` and `Spacer(minLength: 24)` so the button never floats above content.

### Date picker sheets match the new editor

- Working Date / Due Date sheets switched from `Color(.systemGroupedBackground)` + cards to flat `Color(.systemBackground)`. Calendar sits naked in the scroll content.
- **End Date toggle** now uses the same `propertyRow` helper as the Reminder row (small gray icon, 120 pt label column, trailing `Toggle`). The old purple-tile + headline pattern was retired.
- Layout padding aligned with the main editor: 20 pt horizontal, 8 pt top, 24 pt bottom.

### Calendar picker resizing + Today button

- Day-cell metrics bumped to match the Coin project: `dayCellHeight` 44 → 50, endpoint backgrounds 38×38 → 44×44, day-number font 16 → 18, corner radius 11 → 12, range-strip height 34 → 40. The "today" outline opacity / lineWidth nudged up (0.55 → 0.7, 1.4 → 1.5) so the ring reads clearly.
- **New `Today` button** in the header, sitting to the left of the prev-month chevron. Tapping jumps `visibleMonthStart` to today's month and sets the selection — in single mode this selects today, in range mode it sets `start = today` and clears the `end`. Disabled when today falls outside `minimumDate` / `maximumDate`.

### Sheet detents

- Add Task, Edit Task, Working Date, and Due Date sheets all open at **60%** (`[.fraction(0.6), .large]`) with a visible drag indicator. The previous `[.medium, .large]` default meant tasks without notes wasted vertical space on first present; users can still pull up to large when they want the full canvas.

### Toolbar button weight cleanup (project-wide)

- All trailing toolbar buttons (`Done` / `Save` / `Add`) stripped of `.fontWeight(.bold)` so they match the leading `Cancel` button in size and rendering. **23 buttons across 13 files**: AppearanceView (×7), AboutSheets (×5), TagPickerSheet (×2), TaskDetailView (×3), SettingsView, DefaultStatusPickerSheet, ManageTagsView, CardOrderPickerSheet, IconPickerSheet, ManualControlSheet, BoardIconPickerSheet, GroupMenuSheet, StatusPickerSheet (×1 each).
- iOS convention is bold-primary in toolbars, but in this app the bolder weight made paired Cancel/Done look mismatched in height. Going uniform — the disabled-state tint and the action color still distinguish the primary action.
- Body-style CTAs (`Add Tag`, `Add Group`, the bottom `Delete Task`) keep their bold weight — they aren't toolbar siblings.

### Tag chip + property row text sizing

- `TagChip` (non-compact branch only) bumped from `.subheadline.weight(.semibold)` / 10/4 padding / r7 to `.body.weight(.semibold)` / 11/5 padding / r8. Affects the Task detail tag row and the Manage Tags settings list; board card tags use `compact: true` and are unchanged.
- Property row labels and values bumped from `.subheadline` (~15 pt) to `.body` (~17 pt). Icons 14 → 16 pt; row HStack spacing 10 → 12; label column 110 → 120 pt to fit "Due Date" at body size; row min height 36 → 42; inline alarm icon 13 → 15 pt; status pill dot 8 → 9 pt with bumped padding.

## 0.2.0 (build 2) — 2026-05-19

Customization, reminders, and drag-and-drop overhaul.

### Drag-to-reorder rewrite (custom implementation)

- Replaced the previous Reorder button on Groups with **long-press drag-and-drop**. Same affordance now ships on Tags and home-board task cards (within a column and across columns to change status).
- **Live reorder**: undragged siblings slide out of the way as the lifted item passes over them (`withAnimation(.easeInOut(duration: 0.18))`).
- Custom drag (`.draggable(payload:preview:)` + per-row `DropDelegate`) instead of `List.onMove`, so the lifted preview is a clean rounded card with no system white / gray platter behind it.
- Drop proposal is `.move` everywhere — the green `+` copy badge never appears.
- Source row stays visible during the drag (matches iOS Reminders) — sidesteps the "card disappears after drop" cleanup bug.
- Fixed the "first card bounces" issue at the top of a column by skipping the column-outer delegate when the drag is same-column, plus a dynamic-target-index lookup and a no-op check inside `placeTask`.

### Settings → Appearance → Time Format (new)

- New tab between Language and Text Size: **System / 12-hour / 24-hour** tile picker. Mirrors the Coin app's TimeFormatPickerSheet.
- `AppTimeFormat.uses24HourClock` resolves the System case via the device locale (`DateFormatter.dateFormat(fromTemplate: "j", ...)`).

### Settings → Default → Status (new)

- New row at the top of the Default section: pick which group new tasks land in when created from the bottom-bar `+` button.
- `DefaultStatusPickerSheet` mirrors the in-task `StatusPickerSheet` (3-column tile grid of groups with their colored dot, name, and task count).
- Persisted on `SettingsViewModel.defaultGroupID` (UserDefaults key `task.defaultGroupID`) as the group's UUID string. `SettingsViewModel.defaultGroup(in:)` resolves it back to a `BoardGroup`, with an automatic fallback to `board.orderedGroups.first` when the stored ID is missing or the group has since been deleted.
- `RootView` uses the resolved default group when presenting the new-task sheet; the existing in-task Status picker is unchanged.
- The Settings row icon is a `circle.fill` tinted with the selected group's color and the row value shows the group name.

### Card footer divider (changed)

- The notes (`doc.text`) and reminder (`alarm`) icons moved from the top-left of the card and the matching date row to a single footer row at the bottom of the card.
- The footer renders as `─── icon ───`: a thin separator (`Color(uiColor: .separator)`, 0.5 pt) on each side with the icons (`caption2`, `.secondary`) centered between them. Both icons share one row when both are set; the row is omitted entirely when neither applies.
- `DateRow` / `DueDateRow` dropped their `hasReminder` parameter — the alarm no longer rides along with the date — which also retires the `primaryReminderDate`-vs-`dueDate` comparison the card previously needed to decide which row owned the alarm. Notification scheduling in `NotificationService` still fires on `primaryReminderDate` and is unchanged.

### Settings → Default → Reminder Time (new)

- New tab below Card Order: hour/minute that per-task reminders fire on the chosen date. **Default 9:00.**
- Custom HH:MM numeric keypad sheet (`ReminderTimePickerSheet`), button dimensions matched to Coin exactly: 62 pt min-height, 12 pt spacing, 26 pt corner radius, 28 pt rounded-bold digits, 0.68 min scale factor.
- Opens with an "Enter Time" placeholder (does not pre-load the current value). Live preview replaces the placeholder as digits are typed (e.g., `900` → `9:00`, `2130` → `21:30`). `Done` stays disabled until a valid time is entered.
- `Now`, `C`, `⌫`, `00` shortcuts; in 12-hour mode an `AM/PM` toggle replaces a placeholder slot in the bottom row.
- Sheet uses `.height(560)` detent.
- `NotificationService.schedule(for:)` now reads `ReminderDefaults.storedMinutesOfDay()` instead of the previously hardcoded `9:00`. The default and key live on a top-level nonisolated `ReminderDefaults` enum so the nonisolated notification service can read them without crossing the `SettingsViewModel` `@MainActor` boundary.

### App Accent color normalization

- `AppAccent.color` now returns pure SwiftUI system colors (`.blue`, `.purple`, `.pink`, `.green`, `.red`, `.gray`) — previously these six returned muted custom `ColorKey.hue` RGB values. Orange / teal / indigo were already system colors. Matches Coin's `AppHighlightColor` exactly.

### Tag sortIndex + drag-reorder + backward-compat import

- Added `var sortIndex: Int = 0` to `TaskTag` and updated `Board.orderedTags` to sort by `sortIndex` then `createdAt` as the tiebreaker (so existing tags with the default `0` stay in their original creation order).
- `TagExport` JSON now writes `sortIndex`; the import path is backward-compatible via a custom `init(from:)` that uses `decodeIfPresent` (missing field → `0`). Older 0.1.0 exports import cleanly.
- New tags created through `ManageTagsView.addTag` and `TagPickerSheet.addTag` get the next incremental `sortIndex` and land at the end.

### Settings tab renames

- `Customization` rows: **Manage Groups** → **Groups**, **Manage Tags** → **Tags**.

### Components

- `GridTile` gained an `iconText:` parameter, so a tile can render "12" / "24" text inside the tinted square (used by `TimeFormatPickerSheet`).
- New `TimeFormatting.format(hour:minute:uses24Hour:)` helper in `DateFormatters.swift` — shared by the Reminder Time row summary and the picker preview.

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
