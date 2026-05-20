# Version History

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
