# Task — Issues Report

Audit of branch `task-v0.4.7` on 2026-05-22. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.4.7 (build 4 per `VersionHistory.md` and `project.pbxproj`) is in
very good shape. Almost every Medium item from
`docs/IssuesArchive-03.md` is resolved: `settings.dateFormat` is now
plumbed through `TaskDetailView`, `SearchView`, `DateRow`, `DueDateRow`,
and `NotificationService` (via `TaskDateFormat.currentStyle`); changing a
board's Reminder Time re-schedules every active reminder
(`ReminderTimePickerSheet.rescheduleReminders`); repeat reminders refresh
their 16-task batch on scene-active (`RootView.refreshRepeatReminders`)
so a Daily reminder no longer goes silent after 16 days; the drag
rollback watchdog re-arms from `dropUpdated` via `onDragTick` so a slow
hover no longer triggers mid-drag rollback; the four "Untitled" sites
all use `String(localized: "Untitled")`; new boards land with empty
title/subtitle and rely on `TextField(prompt:)` instead of persisting
"Choose a Title"; `HowToUseSheet`'s Boards step now reads "archive
button"; the "More +N" chip renders as "More · N left"; the widget
extension ships `PrivacyInfo.xcprivacy`; signing moved to
`Config/Signing.xcconfig` with a `.local.xcconfig` override; the three
reorder DropDelegates consolidated into the generic
`ReorderDropDelegate<Item>`. zh-Hans coverage climbed to 97% (7 keys
still missing). Remaining issues are all Low: the new sheet action
labels (Add a Status / Add a Tag / Edit a Status / Edit a Tag /
Duplicate Task / Edit Default Status / Current default: %@) lack
zh-Hans translations; `GroupMenuSheet`'s `"None"` fallback for empty
default-status is a raw literal that renders untranslated even on
Chinese builds; `TimeFormatting.format` embeds "AM"/"PM" as
non-localized strings so the Reminder Time row shows English meridiem
even in zh-Hans; the AM/PM keypad toggle button uses the same bare
literals; `Date.formatted(...)` callsites in `CalendarPicker` and the
board date slider use the device locale instead of `TaskDateFormat.locale`;
`MarkdownNotesEditor`'s "Add notes" placeholder is set via UILabel and
never localized; `TaskDetailView.save` silently clears `hasReminder` when
the picked anchor + the board's reminder time falls in the past, with
no toast or warning; `TagPickerSheet.addTag` silently no-ops on a
duplicate name instead of selecting the existing tag like
`StatusPickerSheet.addGroup` does; `CardOrderPickerSheet` commits on
tap but exposes a misleading Cancel toolbar button. The README still
says "0.4.7 (build 1)" while VersionHistory and pbxproj are at build 4.
The bare `TaskDateFormat.format(_:)` and `formatRange(_:_:)` overloads
are now dead code, and the two repo-root review artifacts
(`Issues-cx.md`, `Issues-gg.md`) remain unreferenced. Areas reviewed:
models, services, view models, all views (board, board switcher, task
detail with the new Duplicate Task flow, status/tag picker sheets,
search, settings, customization, about, components including the new
`ReorderDropDelegate`), widget target, project configuration including
the new `Signing.xcconfig`, entitlements, privacy info, and
`Localizable.xcstrings` coverage. Not reviewed: live runtime behavior
on device, on-device notification delivery, Instruments traces, asset
catalog contents.

---

## 2. Issue list

### N1. 7 `Localizable.xcstrings` keys still missing zh-Hans translations

- **Severity:** Low
- **Related files:** `Task/Localizable.xcstrings`,
  `Task/Views/Task/TaskDetailView.swift:199,206`,
  `Task/Views/Task/StatusPickerSheet.swift:269,276,285`,
  `Task/Views/Task/TagPickerSheet.swift:276,283,292`,
  `Task/Views/Board/GroupMenuSheet.swift:97`,
  `Task/Components/GroupHeaderPill.swift:36`
- **Description:** A Python `json.load` over the catalog reports 258
  total keys and 251 zh-Hans `state: "translated"` (97.3%, up from
  91.5% in the prior audit). The 7 still-missing keys are all visible
  in v0.4.7's redesigned sheets:
  - `"Add a Status"` — `StatusPickerSheet.addButton`
  - `"Add a Tag"` — `TagPickerSheet.addButton`
  - `"Edit a Status"` — `StatusPickerSheet.editButton`
  - `"Edit a Tag"` — `TagPickerSheet.editButton`
  - `"Duplicate Task"` — `TaskDetailView.duplicateButton`
  - `"Edit Default Status"` — `GroupHeaderPill` accessibility label
  - `"Current default: %@"` — `GroupMenuSheet`'s default-status line
- **Why it matters:** Chinese users on a status or tag picker, or
  opening the Edit Task sheet, see those bottom actions in English
  while every other label is translated. The accessibility label
  surfaces in VoiceOver. These are all new strings introduced for
  v0.4.7's sheet redesign.
- **Suggested fix:** Open the catalog in Xcode's String Catalog
  editor; the seven keys appear as `New` rows. Filling in the zh-Hans
  column is one pass; no Swift change needed.
- **Risks / dependencies:** None. Pairs naturally with N2 below
  (whose fix changes how the GroupMenuSheet line is composed).

### N2. `GroupMenuSheet.currentDefaultStatusName` renders raw `"None"` to Chinese users

- **Severity:** Low
- **Related files:** `Task/Views/Board/GroupMenuSheet.swift:21-23,97`
- **Description:** The "Current default: …" line under the Default
  for New Tasks toggle is composed as
  `Text("Current default: \(currentDefaultStatusName)")` where
  `currentDefaultStatusName` is `board.defaultGroup?.name ?? "None"`.
  The outer literal becomes the catalog key
  `"Current default: %@"` (currently in catalog but missing zh-Hans —
  see N1). The interpolated `%@` is a raw `String`, not a
  `LocalizedStringResource`, so even after the key is translated, a
  board with no resolved default group will render
  `"当前默认: None"` — English `None` inside an otherwise Chinese
  line. The same `RepeatRule.none.displayName` returns
  `String(localized: "None")` ("无" in zh-Hans) so the catalog already
  has the right value; the GroupMenuSheet just bypasses it.
- **Why it matters:** Visible mismatch in Chinese builds whenever the
  user opens Edit Status before picking a default. Subtler than N1
  because it survives the zh-Hans translation pass.
- **Suggested fix:** Replace the fallback with
  `board.defaultGroup?.name ?? String(localized: "None")`. The
  surrounding key still needs translating (see N1), but now the
  interpolated value localizes too.
- **Risks / dependencies:** None.

### N3. `TimeFormatting.format` hardcodes "AM"/"PM" in English

- **Severity:** Low
- **Related files:** `Task/Utils/DateFormatters.swift:66-79`,
  `Task/Views/Settings/SettingsView.swift:268-273`
- **Description:** `TimeFormatting.format(hour:minute:uses24Hour:)`
  builds the 12-hour string with
  `String(format: "%d:%02d %@", displayHour, minute, isPM ? "PM" : "AM")`.
  The "AM"/"PM" arguments are bare `String` literals — `String(format:)`
  performs no localization. Used by
  `SettingsView.reminderTimeLabel`, which is the row value displayed
  beside "Reminder Time" in Settings → Board. Chinese users on
  12-hour clocks see "9:00 AM" / "9:00 PM" inside an otherwise
  Chinese row.
- **Why it matters:** Settings → Board → Reminder Time is a visible
  row; the English meridiem is the only English text in that section
  on a fully translated build.
- **Suggested fix:** Replace the literals with
  `String(localized: "AM")` / `String(localized: "PM")` and add the
  two keys to the catalog with appropriate zh-Hans values ("上午" /
  "下午"). The combined `"AM/PM"` key already exists with
  "上午/下午"; the standalone forms should match.
- **Risks / dependencies:** Need to add two new catalog keys. The
  zh-Hans translation pair is well-established.

### N4. AM/PM keypad button title in `ReminderTimePickerSheet` is not localized

- **Severity:** Low
- **Related files:** `Task/Views/Settings/AppearanceView.swift:381`
- **Description:** The 12-hour keypad's meridiem toggle is wired as
  `key(isPM ? "PM" : "AM", isCompact: true) { isPM.toggle() }`. The
  `key(_:)` helper accepts `title: String?` and renders it via
  `Text(title)` where `title` is `String` — the `LocalizedStringKey`
  overload is bypassed because the type is `String`. So the button
  reads "AM" / "PM" in every locale. The neighboring disabled-state
  label at line 379 uses `String(localized: "AM/PM")` correctly when
  the keypad is in 24-hour mode.
- **Why it matters:** Same class as N3; visible on the 12-hour
  Reminder Time keypad in Chinese.
- **Suggested fix:** Convert to `String(localized: "AM")` /
  `String(localized: "PM")`, reusing the new catalog keys from N3's
  fix.
- **Risks / dependencies:** None. Same translation work as N3.

### N5. `Date.formatted(...)` callsites use the device locale instead of `TaskDateFormat.locale`

- **Severity:** Low
- **Related files:**
  `Task/Components/CalendarPicker.swift:330-332`,
  `Task/Views/Board/BoardView.swift:344,349,370`
- **Description:** Four sites format dates with
  `Date.formatted(_:)` (the new `FormatStyle` API). With no `locale:`
  modifier on the format style, `formatted(_:)` uses
  `Locale.autoupdatingCurrent` — i.e., the **device** locale:
  - `CalendarPicker.monthTitle` (line 331) —
    `visibleMonthStart.formatted(.dateTime.month(.wide).year())`
  - `BoardDateSlider.dateTile` month label (line 344) —
    `day.formatted(.dateTime.month(.abbreviated))`
  - `BoardDateSlider.dateTile` day number (line 349) — typically
    locale-invariant, but the API path is the same.
  - `BoardDateSlider.dateTile` accessibility label (line 370) —
    `day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())`
  Meanwhile, all `DateFormatter`-based paths (`TaskDateFormat.medium`
  and the styled `TaskDateFormat.formatter(for:)` cache) honor
  `TaskDateFormat.locale`, which `SettingsViewModel.language.didSet`
  keeps in sync with the user's pick. An English-device user on
  Chinese sees Chinese cards/editor/search/notifications but English
  calendar headers and date-slider month labels.
- **Why it matters:** Symmetric to the previously-fixed
  `TaskDateFormat.locale` issue (archive 02 N6), reintroduced when
  the project moved a few callsites to the `FormatStyle` API.
- **Suggested fix:** Pass `.locale(TaskDateFormat.locale)` (or read
  the SwiftUI `\.locale` environment via
  `@Environment(\.locale) private var envLocale` and pass that). The
  CalendarPicker is `@Environment`-aware so the environment route is
  more idiomatic; the slider in `BoardView` is also a SwiftUI view.
- **Risks / dependencies:** Verify the formatted strings still render
  correctly under VoiceOver after the locale switch.

### N6. `MarkdownNotesEditor` placeholder is a non-localized UILabel string

- **Severity:** Low
- **Related files:** `Task/Views/Task/MarkdownNotesEditor.swift:6,144,150`
- **Description:** `MarkdownNotesEditor.placeholder` defaults to
  `"Add notes"` (Swift `String`). The string flows into
  `MarkdownUITextView.placeholderLabel.text = placeholder`
  (UIKit's `UILabel.text`, which does not localize). Chinese users
  on the Notes section of every task see "Add notes" in English. The
  SwiftUI `Text(_:)` LocalizedStringKey route is not used.
- **Why it matters:** Notes is the most prominent block on
  `TaskDetailView`; the placeholder is the first thing shown for a
  fresh task and survives every locale switch.
- **Suggested fix:** Default the placeholder to
  `String(localized: "Add notes")`, or compute it from a
  LocalizedStringKey at the SwiftUI boundary and forward the
  resolved `String` to the UIKit subview. Add the key to the
  catalog.
- **Risks / dependencies:** None.

### N7. `TaskDetailView.save` silently clears `hasReminder` when the resolved fire time is already past today

- **Severity:** Low
- **Related files:** `Task/Views/Task/TaskDetailView.swift:545-553,599-614`
- **Description:** During save the code computes
  `candidateFireDate()`, which mirrors `TaskItem.primaryReminderDate`
  plus `board.reminderMinutesOfDay` for the hour/minute (lines
  599-614). When `intendsReminder && repeatRule == .none && fire <= Date()`
  (lines 549-552), `task.hasReminder` is flipped to `false`. The user
  is not notified. The sheet dismisses normally; re-opening the task
  shows the Reminder toggle as off. Hits when the user picks "today"
  as the date and the board's reminder time has already passed for
  the day.
- **Why it matters:** Same silent-failure class as the prior
  `disableReminderIfNoDates` issue but for a different trigger. The
  user set "Today, remind me," tapped Save, and the reminder was
  dropped without acknowledgment. Less common than the
  no-dates case but visible to anyone who creates a task in the
  evening.
- **Suggested fix:** Surface a small inline note next to the
  Reminder row when the toggle would be cleared at save time
  ("Reminder time has passed for today — choose a future date or
  change Reminder Time"), or flip the toggle visibly during the
  picker step (parallel to `disableReminderIfNoDates`), so the user
  sees the change before tapping Save.
- **Risks / dependencies:** None functional. Decide whether to also
  add a similar inline warning when the user picks tomorrow but
  toggles reminder off then on (today's gone past is the only
  silent path right now).

### N8. `TagPickerSheet.addTag` silently no-ops when a tag with that name already exists

- **Severity:** Low
- **Related files:** `Task/Views/Task/TagPickerSheet.swift:354-369`,
  `Task/Views/Task/StatusPickerSheet.swift:339-356`
- **Description:** `TagPickerSheet.addTag` does a case-insensitive
  duplicate check (line 357): if a tag with the typed name already
  exists, the function clears the input field, dismisses the sheet,
  and returns — without adding the existing tag to the current task's
  `selection`. The user typed an existing tag name, expecting either
  to add it or to be told it was a duplicate; instead the sheet
  closes silently and the tag is not on the task.
- **Why it matters:** Mismatch with the sibling
  `StatusPickerSheet.addGroup` (line 342-347), which does select the
  existing group when a name collides. Tags should give equivalent
  feedback.
- **Suggested fix:** Mirror the StatusPickerSheet behavior. When the
  duplicate branch hits, append the existing tag to `selection`
  (after a `contains(where:)` check so toggling a duplicate doesn't
  add twice) and dismiss. Optionally surface a tiny
  ContentUnavailable-style hint inside the New Tag sheet when the
  field matches an existing tag.
- **Risks / dependencies:** None. ~5 lines.

### N9. `CardOrderPickerSheet` Cancel button is misleading — selection commits on tap

- **Severity:** Low
- **Related files:** `Task/Views/Settings/CardOrderPickerSheet.swift:29-35,80-101`
- **Description:** Each `sortFieldRow` / `sortDirectionRow` button
  writes directly to `board.cardSortField` / `cardSortDirection` and
  saves the context (lines 82-84, 99-101). The toolbar exposes both
  `Cancel` and `Done` (lines 29-34) that just call `dismiss()`. Tapping
  Cancel after picking a new sort doesn't undo the change — it just
  closes the sheet. Same anti-pattern that the prior audit (archive
  02 N5) flagged in `BoardIconPickerSheet`, which now uses
  `pendingIcon` + `Done` semantics correctly.
- **Why it matters:** Sets a wrong expectation. Less destructive than
  the icon picker case (sort settings revert by re-tapping the
  previous option) but still inconsistent within the picker family.
- **Suggested fix:** Either (a) remove Cancel and keep only `Done`
  to match the tap-to-commit semantics, or (b) track
  `pendingField` / `pendingDirection` locally and apply on Done.
  Option (a) is the smaller patch and matches
  `FlatSettingsChoicePicker`'s family (Theme / Accent / etc.) — but
  those use Cancel+Done both as `dismiss()`. Pick one rule and apply
  consistently.
- **Risks / dependencies:** Touches one file. The same rule should
  apply to the FlatSettingsChoicePicker family if option (a) is
  adopted.

### N10. README says "0.4.7 (build 1)" but VersionHistory and `project.pbxproj` are at build 4

- **Severity:** Low
- **Related files:** `README.md:9`, `VersionHistory.md:3`,
  `task.xcodeproj/project.pbxproj:453,490,525,554,580,605`
- **Description:** README's banner reads
  `Current app version: **0.4.7 (build 1)**`. `VersionHistory.md`'s
  most recent entry is `## 0.4.7 (build 4) — 2026-05-23`. The pbxproj
  has `CURRENT_PROJECT_VERSION = 4` on every target configuration
  (lines 453, 490, 525, 554, 580, 605). Same drift class the prior
  audit raised, now reintroduced.
- **Why it matters:** Minor docs drift. The app's Settings → About →
  Version reads "0.4.7 (4)", contradicting the README.
- **Suggested fix:** Bump the README banner to
  `0.4.7 (build 4)` to match the current pbxproj. If a build 1 was
  the intended public release, the pbxproj should be reverted —
  but recent commits (`29b125a Polish task editing sheets`) suggest
  build 4 is the intentional state and the README simply wasn't
  updated.
- **Risks / dependencies:** None.

### N11. Bare `TaskDateFormat.format(_:)` and `formatRange(_:_:)` overloads are now dead code

- **Severity:** Low
- **Related files:** `Task/Utils/DateFormatters.swift:43-52`
- **Description:** `grep -rn 'TaskDateFormat.format' Task TaskWidgetExtension --include='*.swift'`
  returns 8 callsites, all of which pass `style:`. The two
  non-styled overloads (`format(_ date: Date)` and
  `formatRange(_ start: Date, _ end: Date?)`) have no remaining
  callers in production. They were kept as a safety net during the
  archive-02 N1 fix; now that every site is styled, the unstyled
  pair is dead.
- **Why it matters:** Slow accretion of dead code. Also a small
  footgun — a future contributor might call the bare overload and
  silently lose the user's chosen Date Format style on a new
  surface.
- **Suggested fix:** Delete `TaskDateFormat.format(_:)` and
  `TaskDateFormat.formatRange(_:_:)` (the styled overloads stay).
  The `TaskDateFormat.medium` formatter underneath is still needed
  if any future code wants `.medium` style explicitly, but no caller
  uses it directly today — it could collapse into a private cache
  for `formatter(for: .shortText)` if the AppDateFormat enum gains
  a "medium" case.
- **Risks / dependencies:** None — the styled pair is in use
  everywhere.

### N12. `ReminderTimePickerSheet.rescheduleReminders` doesn't yield in its loop

- **Severity:** Low
- **Related files:** `Task/Views/Settings/AppearanceView.swift:477-481`
- **Description:** After the user changes the board's Reminder Time,
  the sheet walks `board.tasks?.filter(\.hasReminder)` and calls
  `NotificationService.schedule(for:)` for each, with no
  `Task.yield()`. The test data boards ship ~125 tasks each; the
  number of tasks with `hasReminder = true` is a subset, but a
  power user with 200+ active reminders would see the main thread
  block for the full re-schedule before the sheet dismisses. Compare
  to `DataImportExport.mergeBoard` (line 485-487) which yields every
  50 tasks.
- **Why it matters:** Minor jank, only visible on large boards.
- **Suggested fix:** Convert `rescheduleReminders` to `async` and
  yield every 50 tasks; call it from `applyAndDismiss` via a
  detached `Task { @MainActor in ... }` so the sheet dismisses
  immediately and the reschedule runs in the background. The
  `dismiss()` already happens synchronously; only the loop needs to
  move off the critical path.
- **Risks / dependencies:** None. The notification API itself is
  already non-blocking.

### N13. `ColumnView.groupDragPrefix` constant defined but the literal `"group:"` is used at the parse site

- **Severity:** Low (carryover from prior archive)
- **Related files:** `Task/Views/Board/ColumnView.swift:26,57,266-267`
- **Description:** Line 26 declares
  `private let groupDragPrefix = "group:"`. The drag payload uses it
  at line 57 (`"\(groupDragPrefix)\(group.id.uuidString)"`). But the
  parse site inside `TaskRowDropDelegate.performDrop` (lines
  266-267) uses the bare literal `"group:"` twice. Renaming or
  changing the constant doesn't propagate to the prefix check.
- **Why it matters:** Drift risk. A future change to the prefix
  would silently break the parse without a compile error.
- **Suggested fix:** Either (a) move the constant out of `ColumnView`
  to a file-scope constant `private let groupDragPrefix = "group:"`
  that both the encode and decode sites can read, or (b) drop the
  constant entirely and inline `"group:"` in both places. Option
  (a) is the cleaner long-term fix.
- **Risks / dependencies:** None.

### N14. `Issues-cx.md` and `Issues-gg.md` linger at the repo root

- **Severity:** Low (carryover from prior archive)
- **Related files:** `Issues-cx.md` (23.3 KB), `Issues-gg.md` (16.9 KB)
- **Description:** Both files exist at the repo root and are not
  linked from any internal markdown (`grep -rn "Issues-cx\\|Issues-gg"
  --include='*.md'` only matches the prior archive's "Not checked"
  note). They appear to be external review artifacts from a one-off
  pass. They still travel with the repo.
- **Why it matters:** Confusion for a future contributor browsing
  the repo root. If they were valuable references, they should live
  under `docs/`; if not, delete.
- **Suggested fix:** Decide their disposition and either
  `git mv Issues-cx.md docs/Issues-cx.md` (and same for `-gg`) or
  `git rm` them. Either keeps the repo root tidy.
- **Risks / dependencies:** None.

---

## 3. Code quality findings

- **Duplicated code:**
  - 25 sites call `try? context.save()` directly. Many also call
    `UpcomingSnapshotBuilder.writeSnapshot(from: context)` immediately
    after (15 sites do, ~10 skip — mostly correctly, since tag
    changes don't surface in the widget). A single
    `BoardWriter.save(_:context:writeSnapshot:Bool = true)` helper
    would funnel them through one place and let a future debounce
    of `WidgetCenter.reloadAllTimelines()` land cleanly. Same point
    archive 02 N14 raised.
  - `ColorKey` (Task target) and `WidgetColorKey`
    (TaskWidgetExtension target) re-declare the same seven RGB
    tuples and `hue` accessors. They must be updated in lockstep.
    Same point archive 02 raised; could share a tiny source-only
    file via synchronized folder exception inversion.
  - `SharedDefaultsService.UpcomingSnapshotEntry` (app side, all
    fields non-optional) and `WidgetUpcomingEntry` (widget side,
    `boardID`/`boardEmoji`/`boardTitle` Optional) describe the same
    JSON shape with differing optionality. The Optionality difference
    is deliberate — the widget side has to decode older snapshots
    without the multi-board fields — but the field-name agreement
    is currently maintained by hand.

- **Unused or outdated files / symbols:**
  - `TaskDateFormat.format(_:)` and `TaskDateFormat.formatRange(_:_:)`
    overloads at `Task/Utils/DateFormatters.swift:43-52` — see N11.
  - `Issues-cx.md` and `Issues-gg.md` at the repo root — see N14.

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` is now 723 lines (up from
    ~600 in the prior audit). The title field + six property rows +
    two date sub-sheets + repeat picker + delete + duplicate
    confirmations + load/save/delete/duplicate + advance +
    candidateFireDate + reminderAnchor + the
    `AppTextSize.taskDetail*Size` private extension all live in one
    file. Splitting `workingDateSheet`, `dueDateSheet`,
    `propertyRow`, the size extension, and the bottom action row
    into their own files would meaningfully reduce the cognitive
    load.
  - `Task/Views/Settings/AppearanceView.swift` is 482 lines and
    still bundles the `FlatSettingsChoicePicker` family with the
    standalone `ReminderTimePickerSheet` keypad. Splitting the
    keypad sheet into `Task/Views/Settings/ReminderTimePickerSheet.swift`
    would let `AppearanceView.swift` shrink to the picker family it
    advertises.
  - `Task/Views/Task/MarkdownNotesEditor.swift` is 461 lines split
    across the SwiftUI editor + the UIKit text view + the inline /
    line markdown style helpers + the parser. The parser
    (`parseNoteLines`, `matchHeading`, `matchBareTask`,
    `matchBulletOrTask`, `matchTaskBody`, `toggleTaskMarker`,
    `toggleTaskBox`) is pure-function and would read better in
    `Task/Views/Task/MarkdownNotesParser.swift`.
  - `Task/Services/DataImportExport.swift:315-491`
    (`mergeBoard(_:into:plan:)`) is ~175 lines that walk groups,
    tags, and tasks merge in a single method. Extracting
    `mergeGroups`, `mergeTags`, `mergeTasks` would keep N7-style
    fixes (notification plan adjustments) small and focused.

- **Naming inconsistencies:**
  - `ColumnView.groupDragPrefix` constant vs `"group:"` literal at the
    parse site — see N13.
  - `task.activeBoardID` raw UserDefaults key string is referenced
    at `RootView.swift:10` (`@AppStorage("task.activeBoardID")`) and
    `DataImportExport.swift:517`
    (`UserDefaults.standard.removeObject(forKey: "task.activeBoardID")`).
    No central constant. If renamed, both sites must update.

- **Structural improvements:**
  - Centralize the `try? context.save() + UpcomingSnapshotBuilder.writeSnapshot`
    pair behind a `BoardWriter.save(context:)` helper. ~13 callers
    on the snapshot side, ~25 on the save side; the union becomes
    one place to add a future widget-reload debounce or to switch
    away from `try?` if Save errors ever need to surface to the
    user.
  - Move the cross-target color palette (`ColorKey` ↔
    `WidgetColorKey`) into a shared source-only file referenced via
    `PBXFileSystemSynchronizedBuildFileExceptionSet` inversions.

---

## 4. Functional issues

- **Boards** — Default seed (Personal / Study / Work) covered by
  `testSeedCreatesThreeDefaultBoards`. Add board through the switcher
  works and lands as the active board with empty title/subtitle
  (relying on `TextField(prompt:)`). Board reorder via long-press
  drag works via the shared `ReorderDropDelegate<Board>`. Delete via
  expanded sheet → delete mode → confirmation works; cascades
  through tasks and cancels their notifications. Active-board
  fallback on delete uses the next-remaining board.
- **Board / columns / cards** — Pagination, `.id()` re-render on sort
  change, and pull-to-refresh all work. Card drag-reorder correctly
  no-ops in non-Manual sort modes for same-column moves and routes
  cross-column drops to end-of-list. Watchdog rollback re-arms from
  `dropUpdated` so slow drags don't roll back mid-move. The "More
  +N" chip now reads "More · N left".
- **Drag and drop** — Cross-column drops save once via
  `placeTask(commit: true)`. Within-column live drag yields
  smoothly. Drop proposal `.move` everywhere — no green `+` badge.
  Reorder rollback watchdog covers BoardSwitcher / StatusPicker /
  TagPicker.
- **Calendar picker** — Today button works. Range mode after both
  endpoints are set: tapping start swaps end into start and clears
  end; tapping a third date starts a fresh selection. Note: header
  month/year text uses device locale rather than user-picked
  language (N5).
- **Search** — Cross-board search works; active board surfaces first.
  `groupedResults` still recomputes every body update — fine at
  current expected scale but a debounce would help at thousands of
  tasks. Carry-over from prior audit.
- **Default Status picker** — Default Status is now set via the
  Default for New Tasks toggle inside the per-group **Edit Status**
  sheet (`GroupMenuSheet`); the prior header flag button was
  removed in v0.4.7. The new-task sheet uses `board.defaultGroup`
  which falls back to `orderedGroups.first` when the stored ID is
  missing. "Current default: …" line under the toggle renders
  English `None` for empty fallback in zh-Hans builds (N2).
- **Manage Groups / Manage Tags screens** — Done via in-flow surfaces
  (`GroupMenuSheet`, `StatusPickerSheet`, `TagPickerSheet`). All
  three use the consolidated `ReorderDropDelegate`. The delete-mode
  toggle is consistent across all three. `TagPickerSheet.addTag`
  silently no-ops on duplicate names (N8) instead of selecting the
  existing tag like `StatusPickerSheet.addGroup` does.
- **Task editor** — Title field uses `TextField(prompt:)` with
  "Add title" hint. Six property rows (Status, Tags, Working, Due
  Date, Repeat, Reminder). Reminder anchor badge mirrors
  `TaskItem.primaryReminderDate`. Duplicate Task action via the new
  bottom row + ConfirmationSheet with `isDestructive: false`.
  Save's "past fire time today" branch silently clears
  `hasReminder` without notifying the user (N7).
- **Import / Export / Reset** — Round-trips correctly for self-
  exported data. Orphan counts are surfaced via inflection markup
  in the success alert. Reset shows a `ProgressOverlay` and yields
  every 50 tasks during the cancellation loop. Reset returns
  `false` and the UI shows a `resetFailure` alert if the
  destructive save fails. Resets in the in-memory fallback also
  purge the on-disk SQLite store.
- **Notifications** — Past-date guard skips occurrences before now.
  Authorization-denied state surfaces a banner inside
  `TaskDetailView` when `hasReminder` is enabled. Reminder is
  auto-disabled when the user clears the last date. Repeat is
  batched as 16 one-shots and refreshed on app launch /
  scene-active via `RootView.refreshRepeatReminders`. Time-of-day
  is read from the per-board `reminderMinutesOfDay` at schedule
  time and re-applied to existing reminders when the user changes
  the board setting.
- **Widget snapshot** — `UpcomingSnapshotBuilder.writeSnapshot` calls
  `WidgetCenter.shared.reloadAllTimelines()` at the end of every
  rebuild. Snapshot date encoding is `.iso8601` on both sides.
  Board list is rewritten on every snapshot write. The widget's
  `primaryDate` deliberately diverges from
  `TaskItem.primaryReminderDate` to surface tasks that "start
  before they're due"; the snapshot builder's `overlapsWindow`
  function correctly captures ranges that begin before today.
- **Localization** — Catalog covers 97% of keys in zh-Hans, up from
  91.5%. 7 keys still missing (N1). `TaskDateFormat.locale` is
  updated from `SettingsViewModel.language.didSet`. Four
  `Date.formatted(...)` callsites bypass it (N5). One UILabel
  placeholder bypasses SwiftUI localization entirely (N6).

---

## 5. UI/UX issues

- **N1 (zh-Hans missing 7 keys)** — visible to Chinese users on the
  redesigned status/tag picker sheets and the Edit Task bottom row.
- **N2 ("None" raw in GroupMenuSheet default-status line)** —
  English `None` in an otherwise Chinese sentence.
- **N3 (TimeFormatting AM/PM)** — Settings → Board → Reminder Time
  shows English meridiem on Chinese 12-hour builds.
- **N4 (Keypad AM/PM button)** — Same root cause as N3, visible on
  the keypad itself.
- **N5 (Date.formatted device locale)** — Calendar header and
  date-slider tiles use device locale instead of user's pick.
- **N6 (Markdown placeholder unlocalized)** — "Add notes" in
  English even on Chinese builds.
- **N7 (silent hasReminder strip on today + past)** — silent
  failure when picking today as the date and the board's reminder
  time has already passed.
- **N8 (duplicate tag name silently dismisses sheet)** — no
  feedback to the user.
- **N9 (CardOrderPickerSheet Cancel misleading)** — Cancel button
  doesn't undo the sort change.
- **N13 (groupDragPrefix constant vs literal)** — drift risk; not
  user-visible.
- **Drag preview shapes** — all card surfaces use
  `.contentShape(.dragPreview, RoundedRectangle(cornerRadius: …))`
  or `Capsule(...)` for the group pill. No green `+` badge
  anywhere. Matches LessonsLearned guidance.
- **iOS 26 fallback parity** — `BottomNavBar` forks via
  `#available(iOS 26.0, *)`; the iOS 18-25 fallback uses
  `.thinMaterial` + `secondarySystemBackground` circles with the
  same control set.
- **ConfirmationSheet fixed height** — `confirmationSheetPresentationStyle()`
  pins the detent to 360 pt. The Reset confirmation copy
  ("This will delete every board, group, tag, and task on this
  device, then restore the three default boards (Personal, Study,
  Work) with five groups each. This can't be undone.") is the
  longest message anywhere; at very large Dynamic Type sizes it
  could press against the buttons. Not currently observed; flag
  for on-device verification.
- **MarkdownNotesEditor blank-line tap target** — `Color.clear`
  with `frame(height: 8)` and `onTapGesture { beginEditing() }`.
  Narrow hit target; survives from prior audits.
- **`ProjectHeaderView` icon button asymmetry** — Sort icon
  stays neutral even when sort is not Manual. Date Filter icon
  tints when the filter is active. Minor consistency issue.

---

## 6. Data and persistence issues

- **Cascade deletes** — `Board.groups` / `tags` / `tasks` all set
  `deleteRule: .cascade`. `BoardGroup.tasks` uses `.nullify` — so
  deleting a group via SwiftData alone would orphan its tasks.
  Live delete paths (`GroupMenuSheet.deleteAndDismiss`,
  `StatusPickerSheet.deleteGroup`) reassign tasks to the fallback
  group before deleting; the cascade-from-Board path (in
  `BoardSwitcherView.deleteBoard` and `resetAll`) deletes everything
  anyway, so no orphan.
- **CloudKit-readiness invariants** hold: every `@Model` property in
  `Board`, `BoardGroup`, `TaskTag`, `TaskItem` has a default value,
  no `@Attribute(.unique)`, optional inverse relationships.
- **In-memory fallback signal** — `RootView` surfaces the alert
  exactly once per launch. `inMemoryFallbackKey` is flipped on next
  successful container open. `resetAll` purges the on-disk store
  files when in fallback so the next launch can rebuild cleanly.
- **Snapshot encoding** — both write paths use `.iso8601`; widget
  decoder matches. App-side `UpcomingSnapshotEntry` (all fields
  non-optional) and widget-side `WidgetUpcomingEntry` (three
  multi-board fields optional) differ in optionality on purpose:
  older snapshots written before multi-board lack
  `boardID/boardEmoji/boardTitle`; the widget tolerates that.
- **`writeBoardList` uses default `JSONEncoder()`** —
  `SharedDefaultsService.swift:55-58` doesn't set
  `dateEncodingStrategy`. `BoardListEntry` has no `Date` fields so
  this is benign today; if a `Date` is ever added, mirror the
  `.iso8601` rule.
- **Export ordering** — `BoardExportEntry.tasks` are written in the
  natural `(board.tasks ?? [])` order; round-trip still works
  because `sortIndex` is persisted, but exports are not
  byte-identical across runs. Same as prior audit.
- **Save-failure paths** — `TaskDetailView.save / delete / duplicate`
  and `DataImportExport.importData` all `try context.save()` with a
  proper `rollback()` on failure. Good defense.
- **`task.activeBoardID` UserDefaults key** is not centralized; see
  §3 naming inconsistencies.

---

## 7. Configuration and platform issues

- **N10 (README "build 1" vs pbxproj build 4)** — docs drift; see
  issue list.
- **`DEVELOPMENT_TEAM`** is now in `Config/Signing.xcconfig` with an
  `#include? "Signing.local.xcconfig"` override path documented in
  `README.md:48`. Each Task / TaskWidgetExtension config references
  it via `baseConfigurationReference`. The Tests target does not
  reference Signing.xcconfig, but the host-app
  `TEST_HOST = $(BUILT_PRODUCTS_DIR)/Task.app/...` lineage means the
  tests still sign through the app.
- **iOS deployment target 18.0** on all four targets — matches
  README requirements. `#available(iOS 26.0, *)` paths in
  `BottomNavBar` remain the only forks.
- **App Group `group.com.ijustin.task`** is configured on both
  `Task.entitlements` and `TaskWidgetExtension.entitlements`.
- **Privacy manifests** — `Task/PrivacyInfo.xcprivacy` and
  `TaskWidgetExtension/PrivacyInfo.xcprivacy` both declare
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  remains excluded; everything else under the synchronized roots
  picks up its target automatically. `PrivacyInfo.xcprivacy` is
  included by virtue of the synchronization (no explicit reference
  in pbxproj needed).
- **Alternate icons** — `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet Midnight Neutral Light"`
  matches `AppIconOption.alternateName`. Catalog contents not
  verified against the build setting.
- **`Swift 5.0`** — still pinned in every target's `SWIFT_VERSION`.
  Documented as a deliberate choice; revisit before any 0.5.x
  feature work.
- **Portrait-only, iPhone-only** — unchanged from prior audit.

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - `NotificationService.schedule` for repeat rules: assert
    `repeatBatchSize` triggers are added with `task.id@offset`
    identifiers, that `cursor` is advanced past `now` before
    laying down the batch, and that `cancel` removes all 16.
  - `RootView.refreshRepeatReminders` on scene-active: pre-load a
    repeating reminder whose batch has only 3 occurrences left and
    assert the next batch lays down a fresh 16 starting from the
    next future occurrence.
  - `ReminderTimePickerSheet.rescheduleReminders` after a time
    change: assert pending triggers' hour/minute reflect the new
    setting. Currently has no coverage.
  - `DataImportExport.importData` round-trip integrity at v2 wire
    format and the v1 legacy fall-back (`LegacySingleBoardPayload`).
  - `DataImportExport.mergeBoard` orphan paths: missing groupID →
    fallback to first group; missing tagID in `tagIDs` → drop tag;
    same-board name-conflict cases.
  - `DataImportExport.resetAll`: cancellation runs for every prior
    task before the seed runs; `task.activeBoardID` is cleared;
    in-memory fallback also purges store files.
  - Group delete reassignment (`GroupMenuSheet.deleteAndDismiss`,
    `StatusPickerSheet.deleteGroup`): tasks land at the tail of
    fallback with monotonically increasing `sortIndex`.
  - `TaskDetailView.save` past-fire-date branch (N7): given today
    as date + board reminder time in the past, assert
    `hasReminder` is false after save.
  - `TaskDetailView.duplicate`: every editable field copies,
    `sortIndex` lands at `original + 1`, downstream siblings
    shift, notifications are re-scheduled on the copy.
  - `TagPickerSheet.addTag` duplicate-name path (N8): typing an
    existing tag name should append the existing tag to the
    selection.
  - Cross-board task isolation: a task added to board A must not
    surface in board B's search or column rendering.
  - Drag-reorder math via the consolidated `ReorderDropDelegate`:
    `applyMove` should be a no-op when `from == to` and renumber
    `sortIndex` only when it changes.
  - Snapshot encode → widget decode round-trip with the new
    multi-board optional fields.

- **Suggested tests:**
  - `testRepeatBatchSchedulesSixteenTriggers()` — set a `.daily`
    repeat with reminder on; assert pending request count is 16
    after a brief sleep to let `add(_:withCompletionHandler:)`
    flush. Test-host entitlements required.
  - `testReminderTimeChangeReschedulesPendingNotifications()` —
    create task with reminder, schedule, change
    `board.reminderMinutesOfDay`, assert the pending trigger's
    `dateComponents` reflect the new hour/minute. Test-host
    entitlements required.
  - `testReminderRefreshExtendsRepeatingBatchOnSceneActive()` —
    schedule a Daily reminder, fast-forward by simulating
    consumption of the first 15 occurrences (or directly clear all
    pending requests except offset 15), call
    `RootView.refreshRepeatReminders`, assert a new 16 are added
    starting from the next live occurrence.
  - `testImportV1LegacyPayloadWrapsIntoSingleEntry()` — feed
    `LegacySingleBoardPayload`-shaped JSON, assert
    `payload.boards.count == 1` and fields match.
  - `testImportOrphanTaskLandsInFirstGroup()` — import a task with
    a non-existent `groupID`, assert task is placed in
    `board.orderedGroups.first` and
    `outcome.orphanTasks == 1`.
  - `testImportOrphanTagRefDropsButPreservesTask()` — import a task
    with an unknown UUID in `tagIDs`, assert
    `outcome.orphanTagRefs == 1` and the task is created with the
    remaining valid tags.
  - `testGroupDeleteReassignsTasksAndRenumbers()` — five tasks in
    group A; delete A via `StatusPickerSheet.deleteGroup`; assert
    all five live in the first remaining group with `sortIndex`
    appended in order after the fallback's existing tail.
  - `testSavePastFireDateClearsReminderForNonRepeatingTask()` —
    pick today as the date with a board reminder time already in
    the past; call save; assert `task.hasReminder == false` and
    that no notification is scheduled.
  - `testReorderDropDelegateAppliesMoveAndRenumbers()` — three
    boards with `sortIndex` 0/1/2; drag board[2] to position 0 via
    the delegate; assert `sortIndex` is 0/2/1 (item moved, others
    renumbered).
  - `testNotificationPastDateSkips()` — set a past dueDate, call
    `NotificationService.schedule`, assert no pending request for
    `task.id.uuidString`. Test-host entitlements required.

- **Manual / device-only:**
  - Verify widget refreshes promptly after task edits in a real
    widget install across all three families (small / medium /
    large) and after a board rename / icon change.
  - Confirm `setAlternateIconName` actually swaps app icons on
    iOS 18 and iOS 26.
  - VoiceOver pass over `BottomNavBar`, `BoardSwitcherView`
    (delete-mode rows), `BoardView`, `TaskDetailView`,
    `MarkdownNotesEditor`, `GroupHeaderPill` (whose accessibility
    label is one of the N1 missing zh-Hans keys).
  - Reproduce N7: create a task on a board with `reminderMinutesOfDay`
    in the past for today; toggle reminder; save; reopen and
    confirm the toggle is off.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — Fill in the 7 missing zh-Hans translations. Single
    catalog pass; unblocks the rest of the localization items
    (N2-N6).
  - **N2** — Have `GroupMenuSheet.currentDefaultStatusName` return
    `String(localized: "None")` so the catalog value is honored.
    One-line change.
  - **N7** — Pick a surface — inline note, explicit toast, or a
    visible toggle flip — for the silent "fire time has passed
    today" branch in `TaskDetailView.save`. Removes the last
    silent-failure path in the editor.
- **Fix next:**
  - **N3, N4** — Replace bare `"AM"` / `"PM"` literals with
    `String(localized:)` and add the matching catalog keys.
    Settings → Board → Reminder Time and the keypad both pick up
    the fix.
  - **N5** — Pass `.locale(TaskDateFormat.locale)` (or wire
    `@Environment(\.locale)`) to the four `Date.formatted(...)`
    callsites.
  - **N6** — Localize the Markdown editor placeholder.
  - **N8** — Mirror `StatusPickerSheet.addGroup`'s duplicate-name
    behavior in `TagPickerSheet.addTag`.
- **Optional cleanup:**
  - **N9** — Decide and apply a consistent Cancel/Done rule for
    `CardOrderPickerSheet` (and the FlatSettingsChoicePicker family
    if needed).
  - **N10** — Bump README to build 4.
  - **N11** — Delete the dead bare `TaskDateFormat.format(_:)` and
    `formatRange(_:_:)` overloads.
  - **N12** — Convert `ReminderTimePickerSheet.rescheduleReminders`
    to async with a `Task.yield()` per 50 tasks.
  - **N13** — Eliminate the `groupDragPrefix` constant-vs-literal
    drift in `ColumnView`.
  - **N14** — Decide the disposition of `Issues-cx.md` and
    `Issues-gg.md`.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- `docs/IssuesArchive-02.md` cross-referenced against current code
  for every prior issue. N1–N9, N11 (renamed N2 → re-confirmed),
  and N13–N14 from archive 02 resolved; N12 (README build number
  drift) reintroduced and listed as new N10; N6/N7/N12 from prior
  archives confirmed still in good shape.
- `docs/IssuesArchive-01.md` cross-referenced for archive-level
  carryovers (`mediumWithTime`/`isSameDay` dead code,
  `TooMuchToDo`/`Work Harder` defaults, `DefaultStatusPickerSheet`,
  `ManageGroupsView` / `ManageTagsView` orphans — all confirmed
  removed).
- All Swift sources under `Task/`:
  - Models (`Board`, `BoardGroup`, `TaskTag`, `TaskItem`,
    `ColorKey`, `RepeatRule`). `TaskItem` gained the new
    `duplicated(sortIndex:)` helper for v0.4.7.
  - Services (`SwiftDataManager`, `NotificationService`,
    `SharedDefaultsService`, `UpcomingSnapshotBuilder`,
    `DataImportExport`). `NotificationService` now reads
    `TaskDateFormat.currentStyle` for notification bodies and
    advances the cursor past `now` before scheduling a repeat
    batch.
  - Utils (`AppInfo`, `DateFormatters`). `TaskDateFormat` gained
    `currentStyle` mirrored from `SettingsViewModel.dateFormat`.
  - ViewModels (`SettingsViewModel`). Gained
    `notificationsAuthorized` cache + `refreshNotificationAuthorization()`.
  - Views: `RootView` (with the new `refreshRepeatReminders`),
    board (`BoardView` + `BoardDateSliderDayWindow`,
    `BoardSwitcherView`, `ColumnView`, `GroupMenuSheet` with the
    default-status toggle, `ProjectHeaderView`, `TaskCardView`,
    `BoardIconPickerSheet` with `pendingIcon` semantics), task
    (`TaskDetailView` with Duplicate Task, `MarkdownNotesEditor`,
    `RepeatPickerSheet`, `StatusPickerSheet`, `TagPickerSheet`),
    search (`SearchView`), settings (`SettingsView`,
    `AppearanceView` including the `ReminderTimePickerSheet`,
    `CardOrderPickerSheet`, `IconPickerSheet`, `ManualControlSheet`
    with the rewritten reset copy, `AboutSheets` with the rewritten
    HowToUseSheet steps).
  - Components (`BottomNavBar`, `CalendarPicker`, `CardBackground`,
    `ColorSwatchPicker`, `ConfirmationSheet` with the
    `isDestructive: false` mode, `DateRow`, `FlowLayout`,
    `GridTile`, `GroupHeaderPill`, `ProgressOverlay`,
    `ReorderDropDelegate` (new), `SettingsCard` including
    `SheetActionButtonLabel`, `StringMoveDropDelegate`,
    `TagChip`).
- All Swift sources under `TaskWidgetExtension/`
  (`TaskWidgetBundle`, `UpcomingTasksProvider`,
  `UpcomingTasksWidget`, `WidgetSnapshot`,
  `BoardConfigurationIntent`).
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/Info.plist`.
- `Config/Signing.xcconfig` and `task.xcodeproj/project.pbxproj`
  — build settings, synchronized folder exceptions, code signing,
  marketing/current version, INFOPLIST keys, bundle IDs, asset
  catalog config.
- `Task/Localizable.xcstrings` — programmatic count of total keys
  (258) vs zh-Hans `state: "translated"` (251, 97.3%), with the 7
  missing keys enumerated.
- `TaskTests/TaskTests.swift` (12 tests, including the new
  `testTaskDuplicateCopiesEditableFieldsAndRelationships`,
  `testBoardDefaultGroupToggleSetsAndMovesDefaultWhenDisabled`,
  and four `BoardDateSliderDayWindow` window tests).
- Grep queries (via `grep -rn ... --include='*.swift'`):
  - `TODO|FIXME|XXX` (no matches).
  - `Untitled|String(localized` (N1 trace + verifying archive 02
    N5 resolution).
  - `settings.dateFormat|TaskDateFormat.format` (verifying
    archive 02 N1 resolution).
  - `UpcomingSnapshotBuilder.writeSnapshot|WidgetCenter.shared.reloadAllTimelines`
    (snapshot/widget reload trace — 13 writeSnapshot sites).
  - `NotificationService\.` (13 callsites).
  - `try? context.save()` (25 callsites).
  - `mediumWithTime|isSameDay|TooMuchToDo|Work Harder|DefaultStatusPickerSheet|ManageGroupsView|ManageTagsView`
    (verifying archive 01/02 cleanup — no matches).
  - `\.formatted\(` (N5 trace — 4 callsites).
  - `groupDragPrefix|"group:"` (N13).
  - `"None"|"Add notes"|currentDefaultStatusName` (N2 / N6).
  - `"AM"|"PM"|"AM/PM"` (N3 / N4).
  - `repeatBatchSize` (verifying N3 / archive 02 N3 resolution).
  - `isResetting|isImporting|isExporting` (verifying archive 02
    N7 resolution).
  - `\.iso8601|dateDecodingStrategy` (snapshot round-trip).
  - `context.rollback` (save-failure defense).

## Not checked (worth a follow-up)

- Actual runtime behavior on iOS 18.x vs iOS 26 devices /
  simulators (Liquid Glass parity, alternate icon transitions,
  drag previews, the ProgressOverlay animation while a `@MainActor`
  reset runs to completion, widget reload cadence under heavy
  edit churn).
- On-device notification delivery, authorization-denied paths,
  and notification body composition in different locales —
  particularly the repeat-batch refresh on scene-active.
- Instruments / memory profile for a board with thousands of
  tasks; `SearchView.groupedResults` at scale;
  `UpcomingSnapshotBuilder.writeSnapshot` cost when called rapid-
  fire during a large import.
- Widget rendering under each `WidgetFamily` on a real device,
  and the configuration intent picker after a board rename / icon
  change.
- Asset catalog contents — that the alternate icons
  (`Rose/Violet/Midnight/Neutral/Light`) and their `*Preview`
  siblings actually exist; `INCLUDE_ALL_APPICON_ASSETS = YES` is
  set but the catalog itself is not part of this audit.
  `IconPickerSheet` references `option.previewAssetName`
  directly — a missing asset would render a blank tile.
- Verification of the 7 proposed zh-Hans translation values —
  only the missing English keys are enumerated here.
- Accessibility audit (Dynamic Type extremes, VoiceOver labels,
  hit targets, drag-and-drop accessibility).
- The two repo-root review artifacts (`Issues-cx.md`,
  `Issues-gg.md`) — present but not read; flagged for cleanup
  in N14.
- `TestData/testdata.json` integrity — not diff-walked.
- N7 device behavior: reproducing the silent
  `hasReminder = false` strip needs a real on-device run with the
  board's reminder time deliberately set to a past value for
  today.
