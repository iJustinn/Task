# Task — Issues Report

Audit of branch `task-v0.4.7` on 2026-05-23. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.4.7 (build 5 per `VersionHistory.md`, README, and `project.pbxproj`)
is in very good shape. Every Low from `docs/Issues-cc-04.md` is resolved:
all 7 missing zh-Hans keys are translated (catalog now reports 196 active
keys all in `state: "translated"`), `GroupMenuSheet.currentDefaultStatusName`
uses `String(localized: "None")`, `TimeFormatting.format` and the keypad's
AM/PM button use `String(localized: "AM"/"PM")`, `CalendarPicker` and the
`BoardDateSlider` tiles pass `.locale(TaskDateFormat.locale)`, the
Markdown editor placeholder defaults to `String(localized: "Add notes")`,
the editor surfaces an inline warning when the resolved fire time has
already passed today, `TagPickerSheet.addTag` mirrors
`StatusPickerSheet.addGroup`'s duplicate-name behavior,
`CardOrderPickerSheet` dropped its misleading Cancel button, README and
pbxproj agree on build 5, the bare `TaskDateFormat.format(_:)` overloads
are gone, `ReminderTimePickerSheet.rescheduleReminders` is an async
`Task.yield()`-driven loop, `groupDragPrefix` is a file-scope constant
used at both the encode and decode site, and the repo-root `Issues-cx.md`
/ `Issues-gg.md` artifacts now live under `docs/`. The new v0.4.7 build 5
work (status/tag picker redesign, swipe-to-edit, board date slider,
Markdown notes editor and previews, widget board+status filter,
per-task checkbox, biweekly/quarterly/annually repeat options, Storage
Check row, repeat picker chip rows) is functionally sound and well-tested.
The remaining issues are clustered around a single systemic gap:
**custom view parameters typed as `String` instead of `LocalizedStringKey`
bypass both auto-extraction into the catalog and runtime localization
lookup.** This surfaces most visibly in `ConfirmationSheet` (whose
title/message/confirmLabel/cancelLabel are all `String`, so every
destructive confirmation renders in English on Chinese builds) and in
`SettingsButtonRow`/`SettingsRowLabel` (whose `title:`/`value:` are
`String`, so most Settings row labels render in English). Two newer
widget-specific gaps also surface: the widget target has no
`Localizable.xcstrings` of its own (so `String(localized: "Untitled")`
and friends always render English in the widget), and the new
`WidgetUpcomingEntry` does not carry `isChecked`, so a task the user
just ticked still appears prominently in Upcoming Tasks. Areas reviewed:
models, services, view models, all views (board with the new date
slider, board switcher, task detail with the new checkbox row and
duplicate flow, status/tag picker sheets with swipe-to-edit, search,
settings including the new Storage Check row and Notes Preview enum,
customization including the redesigned repeat picker, about, components
including `ReorderDropDelegate`, `SettingsCard`, `ConfirmationSheet`,
`CalendarPicker`, the Markdown notes editor with its UIKit
`LiveMarkdownTextView`), widget target (snapshot shape, configuration
intent, filter logic), project configuration including
`Config/Signing.xcconfig`, entitlements, privacy info,
`task.xcodeproj/project.pbxproj`, and `Localizable.xcstrings` coverage
(273 keys; 77 stale; 196 zh-Hans translated). Not reviewed: live
runtime behavior on device, on-device notification delivery, widget
rendering on a real Home Screen, Instruments traces, asset catalog
contents.

---

## 2. Issue list

### N1. `ConfirmationSheet` title/message/labels are not localized

- **Severity:** High
- **Related files:** `Task/Components/ConfirmationSheet.swift:3-11,30-66`,
  `Task/Views/Task/TaskDetailView.swift:130-154`,
  `Task/Views/Task/StatusPickerSheet.swift:78-90`,
  `Task/Views/Task/TagPickerSheet.swift:86-98`,
  `Task/Views/Board/GroupMenuSheet.swift:65-75`,
  `Task/Views/Board/BoardSwitcherView.swift:70-82`,
  `Task/Views/Settings/ManualControlSheet.swift`
- **Description:** `ConfirmationSheet` declares all four user-facing
  strings as plain `String` (`let title: String`, `let message: String`,
  `var confirmLabel: String = "Delete"`, `var cancelLabel: String = "Cancel"`).
  The render path is `Text(title)`, `Text(message)`, `Text(confirmLabel)`,
  `Text(cancelLabel)` — and `Text<S: StringProtocol>(_ content: S)`
  documents itself as "displays a stored string without localization."
  Two follow-on effects:
  - The literals at the callsites (e.g. `title: "Delete Task?"`,
    `message: "This task and any reminder you set will be removed
    permanently."`) are *not* auto-extracted into the catalog because
    the parameter type is `String`, not `LocalizedStringKey`. A spot
    check confirms: `"Delete Task?"`, `"Duplicate Task?"`,
    `"This task and any reminder you set will be removed permanently."`,
    and `"A copy of this task will be created in the same status."`
    are all MISSING from `Task/Localizable.xcstrings`.
  - Even for strings that *are* in the catalog (e.g. `"Delete Status"`,
    `"Delete Tag"`, `"Delete Board"` are active and translated because
    they appear elsewhere — `SheetActionButtonLabel.title:
    LocalizedStringKey`, `BoardSwitcherView.swift:53`'s ternary
    `navigationTitle`), the `Text(stringVar)` site bypasses the catalog
    lookup, so the rendered text is the literal English.
  Net effect: on a Chinese build, *every* destructive confirmation
  (Delete Task / Duplicate Task / Delete Status / Delete Tag / Delete
  Board / Reset All Data) renders title, message, and both buttons in
  English. This is the single largest user-visible localization gap.
- **Why it matters:** Destructive flows are exactly where the user wants
  clear, native-language copy. The current state mixes Chinese
  surrounding UI with English confirmation panels.
- **Suggested fix:** Change `ConfirmationSheet`'s four user-facing
  parameters to `LocalizedStringKey`:
  ```swift
  let title: LocalizedStringKey
  let message: LocalizedStringKey
  var confirmLabel: LocalizedStringKey = "Delete"
  var cancelLabel: LocalizedStringKey = "Cancel"
  ```
  No callsite changes required — every callsite passes string literals
  that already conform to `LocalizedStringKey`'s
  `ExpressibleByStringLiteral`. After the change, the literals get
  auto-extracted and `Text(localizedKey)` looks up the catalog at
  runtime. Add the four currently-missing keys plus their zh-Hans
  translations.
- **Risks / dependencies:** None functional. The catalog will gain a
  few new keys; the existing `testStringCatalogHasTranslatedZhHansForActiveKeys`
  test will gate them.

### N2. `SettingsButtonRow`/`SettingsRowLabel` titles render in English on Chinese builds

- **Severity:** High
- **Related files:** `Task/Components/SettingsCard.swift:52-89,107-132`,
  `Task/Views/Settings/SettingsView.swift:154-385`
- **Description:** Both `SettingsButtonRow` and `SettingsRowLabel`
  declare `let title: String` and render it via `Text(title)`. Every
  Settings row passes a string literal (`SettingsButtonRow(title:
  "Theme", ...)`, `SettingsRowLabel(title: "iCloud Sync", value:
  "Coming Soon", ...)`, etc.), which is stored as `String` and never
  localized at runtime. Catalog evidence — keys that should
  correspond to Settings row labels but are now marked stale (no
  current auto-extraction site, only the orphaned translation from
  prior builds):
  - `"iCloud Sync"`: stale, zh-Hans translated
  - `"Coming Soon"`: stale, zh-Hans translated
  - `"Storage Check"`: stale, zh-Hans translated
  - `"Theme"`: stale, zh-Hans translated
  - `"Language"`: stale, zh-Hans translated
  - `"Time Format"`: stale, zh-Hans translated
  - `"Version"`: stale, zh-Hans translated
  Three labels are MISSING from the catalog entirely (so they
  were never extracted by any build):
  - `"Date Filter"` — Settings → Board → Date Filter row title
  - `"Date Format"` — Settings → Board → Date Format row title
  - `"Notes Preview"` — Settings → Board → Notes Preview row title
  Result on a Chinese build: many Settings row titles read in English
  ("Theme", "Time Format", "iCloud Sync", "Coming Soon", "Storage Check",
  "Date Filter", "Date Format", "Notes Preview", "Version") while their
  *values* (which are passed through `SettingsViewModel`'s enum `.label`
  computed properties that call `String(localized: ...)`) render in
  Chinese. Same class as N1, but for the read-only Settings surface.
- **Why it matters:** Settings is one of the most-traveled surfaces of
  the app, and Chinese users currently see a mix of English row titles
  and Chinese row values. Inconsistent and unprofessional.
- **Suggested fix:** Same shape as N1 — change `SettingsButtonRow.title`,
  `SettingsRowLabel.title`, and `SettingsRowLabel.value` to
  `LocalizedStringKey`. (For `value`, the existing callers either
  pass `String(localized: ...)`-derived values, which still work, or
  call `trailing(value: ...)` separately — left unchanged.) Add the
  three currently-missing keys (`Date Filter`, `Date Format`,
  `Notes Preview`) plus their zh-Hans translations, and the catalog
  will surface the seven currently-stale keys back to active during
  the next build.
- **Risks / dependencies:** Touches one component file and triggers
  auto-extraction of about a dozen Settings row labels. The catalog
  test will catch any missing zh-Hans translation in the next CI run.

### N3. `StatusPickerSheet.sheetTitle` and `TagPickerSheet.sheetTitle` are not localized

- **Severity:** Medium
- **Related files:** `Task/Views/Task/StatusPickerSheet.swift:62,112-115`,
  `Task/Views/Task/TagPickerSheet.swift:70,122-125`
- **Description:** Both picker sheets compute their navigation title
  through a `String`-typed property:
  ```swift
  private var sheetTitle: String {
      if deleteMode { return "Delete Status" }   // or "Delete Tag"
      return "Choose Status"                     // or "Choose Tags"
  }
  ```
  The call `.navigationTitle(sheetTitle)` picks the
  `.navigationTitle<S: StringProtocol>(_:)` overload (no
  localization). Catalog evidence: `"Choose Status"` and `"Choose Tags"`
  are both stale with valid zh-Hans translations that never get used;
  `"Delete Status"` and `"Delete Tag"` are active in the catalog only
  because they appear in other contexts (`SheetActionButtonLabel`
  callsites and `ConfirmationSheet.confirmLabel`), but the
  navigation-bar render path still misses the lookup.
  Net effect: a Chinese user opens "选择标签" from the editor's Tags row
  and sees "Choose Tags" written across the navigation bar.
- **Why it matters:** Same problem as N1/N2 but localized to a different
  surface. Less frequent than Settings but every Status or Tag pick
  hits it.
- **Suggested fix:** Make the computed property return
  `LocalizedStringKey`:
  ```swift
  private var sheetTitle: LocalizedStringKey {
      if deleteMode { return "Delete Status" }
      return "Choose Status"
  }
  ```
  Both literals are already auto-extracted via the new return type. No
  callsite change needed. Equivalent fix for `TagPickerSheet`.
- **Risks / dependencies:** None. The two "Choose Status" / "Choose
  Tags" stale keys become active again with their existing
  translations.

### N4. `TaskWidgetExtension` target has no `Localizable.xcstrings` of its own

- **Severity:** Medium
- **Related files:** `TaskWidgetExtension/UpcomingTasksWidget.swift:41,92,95,110`,
  `TaskWidgetExtension/BoardConfigurationIntent.swift:27,61,62`,
  `task.xcodeproj/project.pbxproj`
- **Description:** The widget extension calls
  `String(localized: "Untitled")` (three sites) and
  `String(localized: "Upcoming")` (one site), and uses
  `Text("No upcoming")` / `Text("No upcoming tasks")` literals. The
  widget extension target's bundle ships **no** `Localizable.xcstrings`
  file — only the app target has one at
  `Task/Localizable.xcstrings`. `String(localized:)` looks up the
  *calling bundle*, which for the widget is the widget's bundle, which
  has no catalog. So every widget string falls back to its literal
  English value regardless of `settings.language`.
  Catalog evidence: `"No upcoming"`, `"No upcoming tasks"`, and
  `"Upcoming"` are all stale in `Task/Localizable.xcstrings` with
  valid zh-Hans translations ("暂无", "暂无即将开始的任务", "即将开始")
  that the widget never resolves. `String(localized: "Untitled")` from
  the widget has a different bundle context than the app's.
- **Why it matters:** A user on a Chinese device with the Upcoming
  Tasks widget pinned sees English "Upcoming", "No upcoming",
  "Untitled" inside the widget while the rest of the app reads
  Chinese.
- **Suggested fix:** Two options:
  - (a) Add a `TaskWidgetExtension/Localizable.xcstrings` catalog and
    list those few keys (Untitled / Upcoming / No upcoming / No
    upcoming tasks). Smaller, target-isolated.
  - (b) Add `Task/Localizable.xcstrings` to the widget target's
    sources via a `PBXFileSystemSynchronizedBuildFileExceptionSet`
    inversion. Larger payload — every app string ships into the
    widget bundle — but only one catalog to maintain.
  Option (a) is recommended; the widget has a small fixed string set.
- **Risks / dependencies:** Build-setting change in the widget
  extension target. Need to add the new keys plus zh-Hans values; the
  existing translations in the app catalog are a starting point.

### N5. Widget snapshot omits `isChecked`, so checked tasks still appear

- **Severity:** Medium
- **Related files:** `TaskWidgetExtension/WidgetSnapshot.swift:22-45`,
  `Task/Services/SharedDefaultsService.swift:13-26`,
  `Task/Services/UpcomingSnapshotBuilder.swift:35-52`,
  `Task/Views/Board/ColumnView.swift:162-170`
- **Description:** v0.4.7 added a per-task checkbox
  (`TaskItem.showsCheckbox`, `TaskItem.isChecked`) and a tap-to-toggle
  affordance on board cards. The toggle persists to SwiftData and
  visibly strikes through the card title (`TaskCardView.titleRow`'s
  `.strikethrough(isVisiblyChecked, ...)`). But neither
  `SharedDefaultsService.UpcomingSnapshotEntry` nor the widget-side
  `WidgetUpcomingEntry` carries `isChecked`. After the user taps the
  checkbox in the app, the next widget refresh still renders the task
  in its prominent un-struck state — there is no visible signal on
  the widget that the task is done.
- **Why it matters:** The checkbox is a new "lightweight done" gesture
  in v0.4.7. Users who set the widget to mirror today's work expect a
  task they just ticked to either dim, strike through, or disappear
  from the widget. Today none of those happen.
- **Suggested fix:** Decide the widget behavior, then plumb it:
  - (a) Hide checked tasks: filter out
    `task.showsCheckbox && task.isChecked` inside
    `UpcomingSnapshotBuilder.writeSnapshot`'s `overlapsWindow`
    branch. No new field needed; the entry just doesn't write.
    Simplest. Pairs with the user's mental model that "checked = off
    the list."
  - (b) Show checked tasks but render them differently: add
    `isChecked: Bool` (default `false` for legacy decode) to both
    `UpcomingSnapshotEntry` and `WidgetUpcomingEntry`; the widget
    can then strike through or dim the row.
  Either way, `ColumnView.toggleTaskChecked` already writes the
  snapshot — that work pays off after this change (currently it does
  nothing visible; see N8).
- **Risks / dependencies:** Snapshot schema change. The widget side
  already tolerates older snapshots via Optional fields; pattern the
  new field the same way.

### N6. Widget status filter accepts statuses from a different board

- **Severity:** Medium
- **Related files:** `TaskWidgetExtension/BoardConfigurationIntent.swift:93-119`,
  `TaskWidgetExtension/UpcomingTasksProvider.swift:34-46`
- **Description:** `BoardConfigurationIntent` exposes both
  `@Parameter var board: BoardEntity?` and
  `@Parameter var status: StatusEntity?` independently. The widget's
  edit-configuration sheet presents every status across every board
  (`StatusEntityQuery.suggestedEntities` returns
  `WidgetSharedDefaults.readStatusList()` unfiltered), with each
  status's subtitle showing the parent board. Nothing prevents the
  user from picking, say, **Personal** as the board and a **Doing**
  status that belongs to Work. The filter logic then ANDs the two
  conditions:
  ```swift
  if let boardID, entry.boardID != boardID { return false }
  if let statusID, entry.groupID != statusID { return false }
  ```
  No task can satisfy both, so the widget renders "No upcoming"
  permanently until the user notices and adjusts.
- **Why it matters:** Silent dead-end. The widget edit sheet is a
  one-shot — most users won't realize the mismatch and will assume
  the widget is broken.
- **Suggested fix:** Either filter `StatusEntityQuery.suggestedEntities`
  by the currently-selected `BoardEntity` (using
  `IntentParameterDependency` so the picker rebuilds when the board
  changes), or detect a mismatched selection in the provider and
  surface a small "Pick a status on this board" hint in the widget
  view. The first option is the standard AppIntents pattern.
- **Risks / dependencies:** AppIntents `IntentParameterDependency`
  was added in iOS 17 and is well supported on the 18+ deployment
  target. Verify the dependency triggers an automatic picker rebuild
  in the widget edit sheet on iOS 18 and iOS 26.

### N7. Repeat advance `→` button accessibility label says "Reset to next occurrence"

- **Severity:** Low
- **Related files:** `Task/Views/Task/TaskDetailView.swift:381-394,651-658`
- **Description:** The `→` chip in the Repeat row of the editor calls
  `advanceRepeatDates()`, which shifts every set date
  (`workingStart`, `workingEnd`, `dueDate`) **forward** by one
  occurrence of the current rule. Its accessibility label reads
  `Text("Reset to next occurrence")`. "Reset" implies returning to
  some baseline (e.g., today or the original date) — the action does
  the opposite: it pushes the task's whole working window one cycle
  ahead.
- **Why it matters:** VoiceOver users hear "Reset to next occurrence"
  and may expect the rule to reset rather than advance the dates.
  Misleading.
- **Suggested fix:** Rename the label to `"Advance to next occurrence"`
  (or `"Shift to next occurrence"`), and add the new key to the
  catalog with the matching zh-Hans translation. "Reset to next
  occurrence" can be marked stale.
- **Risks / dependencies:** None.

### N8. `ColumnView.toggleTaskChecked` rebuilds the widget snapshot on every tap

- **Severity:** Low
- **Related files:** `Task/Views/Board/ColumnView.swift:162-170`,
  `Task/Services/UpcomingSnapshotBuilder.swift:6-65`
- **Description:** Every time the user taps a checkbox on a board
  card, `toggleTaskChecked` runs
  `UpcomingSnapshotBuilder.writeSnapshot(from: context)` — which
  re-fetches every `TaskItem` and `Board`, rebuilds the upcoming
  list and the status list, writes three JSON blobs into the App
  Group, and triggers `WidgetCenter.shared.reloadAllTimelines()`.
  But `WidgetUpcomingEntry` does not include `isChecked` (see N5),
  so the snapshot's contents are byte-identical to the prior one.
  The widget reload fires for no visible change.
- **Why it matters:** Wasted work — on a board with 125+ tasks each
  checkbox tap costs a full fetch + encode + reload. A user
  power-checking ten items spends ten of those round trips. Pairs
  with N5: once the widget reflects the checkbox state, the
  snapshot rebuild becomes meaningful work; until then it's noise.
- **Suggested fix:** Defer this change until N5 is settled. If N5 is
  fixed by hiding checked tasks (the recommended path), the
  snapshot rebuild becomes useful and this issue closes. If N5 is
  postponed, skip the snapshot write inside `toggleTaskChecked`
  (only `try? context.save()` is needed) and add it back when the
  widget gains the field.
- **Risks / dependencies:** None — both options compose with the
  N5 fix.

### N9. `RepeatPickerSheet.repeatRow` task count lacks plural inflection

- **Severity:** Low
- **Related files:** `Task/Views/Task/RepeatPickerSheet.swift:54-58`,
  `Task/Localizable.xcstrings` (key `%lld tasks`)
- **Description:** Each row in the repeat picker renders
  `Text("\(taskCount(for: rule)) tasks")`. Auto-extraction produces
  the catalog key `"%lld tasks"`. The catalog has it translated to
  `"%lld 个任务"` in zh-Hans, but neither the English source nor the
  zh-Hans translation carries a `variations.plural` block. So
  English users on a board where only one task uses a given rule
  see "1 tasks" (or "0 tasks"). Same shape as the existing
  `BoardSwitcherView.boardRowContent` `"\(taskCount) tasks"`
  callsite.
- **Why it matters:** Minor copy quality issue, visible whenever
  the count is `0` or `1`.
- **Suggested fix:** Either:
  - (a) Use SwiftUI's inflection markup:
    `Text("^[\(taskCount(for: rule)) task](inflect: true)")`. This
    is the same pattern `DataImportExport`'s orphan-message uses.
  - (b) Edit `Localizable.xcstrings` directly to add a
    `variations.plural` block on `%lld tasks` (one for English, one
    for zh-Hans).
  Option (a) is the modern Apple-recommended path.
- **Risks / dependencies:** None. zh-Hans has no plural forms so the
  Chinese translation stays unchanged.

### N10. Catalog has 77 stale keys, some of which match still-rendered English text

- **Severity:** Low
- **Related files:** `Task/Localizable.xcstrings`
- **Description:** A Python `json.load` of the catalog reports 273
  total keys; 77 (28%) are marked `extractionState: "stale"` and
  196 are active. Most stale keys are abandoned strings from
  earlier versions ("Add task", "Add Group", "Choose a Subtitle",
  "Choose a Title", "Date range", "Delete this group?", etc.) and
  can be deleted. Several others — `"Theme"`, `"Language"`,
  `"Time Format"`, `"Storage Check"`, `"Coming Soon"`, `"iCloud Sync"`,
  `"Version"`, `"Choose Status"`, `"Choose Tags"`, `"No upcoming"`,
  `"No upcoming tasks"`, `"Upcoming"` — are stale because the
  corresponding callsites use `String`-typed parameters (see N2 / N3
  / N4) and stop auto-extracting; their zh-Hans translations sit
  unused.
- **Why it matters:** Slow accretion of dead-weight in a synchronized
  file. Also misleading — a contributor looking at the catalog
  might assume those keys are wired up because they have valid
  Chinese translations.
- **Suggested fix:** Order of operations:
  - First land N1 / N2 / N3 / N4. They flip several stale keys back
    to active.
  - After that, run a pruning pass: in Xcode's String Catalog editor,
    sort by extraction state and delete entries that are still stale
    and clearly retired. Keep the ones that are stale because they
    were renamed (so future translators don't lose context).
- **Risks / dependencies:** None. The pruning is one-shot.

### N11. `notesPreviewKey` is "task.notesPreviewEnabled" but stores an enum value

- **Severity:** Low
- **Related files:** `Task/ViewModels/SettingsViewModel.swift:669-671,694`
- **Description:** `SettingsViewModel.notesPreviewKey` is the
  UserDefaults key `"task.notesPreviewEnabled"`. The stored value is
  the raw value of `AppNotesPreview` (one of `none`, `oneLine`,
  `twoLines`, `threeLines`), not a Bool. Git history shows the key
  and the enum were introduced together in commit `547f2d8` ("Add
  Board Style settings section"), so there is no legacy Bool
  encoding in the wild and no user-facing data-loss risk — only the
  `Enabled` suffix in the key name is misleading.
- **Why it matters:** Cosmetic maintenance note. A future maintainer
  might assume a Bool and break the read. No user impact today.
- **Suggested fix:** Optional. If the rename is worth doing, change
  the constant to `"task.notesPreview"` and read both keys in
  `init`, preferring the new key and falling back to the legacy
  one. Drop the fallback after a few releases. Skip if the
  cosmetic cost isn't worth the migration.
- **Risks / dependencies:** None. The legacy key currently holds
  valid enum data, so naive deletion would lose every existing
  user's preference — only do the rename with the dual-read
  migration above.

---

## 3. Code quality findings

- **Duplicated code:**
  - 26 sites call `try? context.save()` directly. 15 of them also
    call `UpcomingSnapshotBuilder.writeSnapshot(from: context)`
    immediately after; the remaining 11 skip the snapshot (correctly,
    since e.g. tag-color tweaks don't surface in the widget). A
    `BoardWriter.save(context:writeSnapshot:Bool = true)` helper
    would funnel both lists through one site and let a future
    debounce of `WidgetCenter.reloadAllTimelines()` land cleanly.
    Same point archive 02 N14 raised.
  - `ColorKey` (Task target) and `WidgetColorKey` (TaskWidgetExtension
    target) re-declare the same seven RGB tuples and `hue`/
    `background` accessors. They must be updated in lockstep. Same
    point archive 02 raised; could share via a synchronized-folder
    inversion. Worth doing in the same PR as N4 (which is the only
    legitimate reason to share files between the two targets).
  - `SharedDefaultsService.UpcomingSnapshotEntry` and
    `WidgetUpcomingEntry` describe the same JSON shape with the
    `boardID`/`boardEmoji`/`boardTitle` and `groupID`/`groupSortIndex`
    fields optional on the widget side (to tolerate older snapshots)
    and required on the app side. Field-name agreement is currently
    maintained by hand — pairs with the `ColorKey`/`WidgetColorKey`
    point.

- **Unused or outdated files / symbols:**
  - `Task/Localizable.xcstrings`: 77 stale keys; see N10. Most can
    be deleted in a pruning pass.

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` is 758 lines (up from
    723 in archive 04). The title field + seven property rows
    (Status / Tags / Working / Due / Repeat / Checkbox / Reminder)
    + two date sub-sheets + repeat picker + delete + duplicate
    confirmations + load/save/delete/duplicate + advance +
    candidateFireDate + reminderAnchor + the
    `AppTextSize.taskDetail*Size` private extension all live in
    one file. Splitting `workingDateSheet`, `dueDateSheet`,
    the property rows, the size extension, and the bottom action
    row into their own files would meaningfully reduce cognitive
    load.
  - `Task/Views/Task/MarkdownNotesEditor.swift` is 461 lines split
    across the SwiftUI editor + the UIKit
    `LiveMarkdownTextView` + the inline / line markdown style
    helpers + the parser. The parser (`parseNoteLines`,
    `matchHeading`, `matchBareTask`, `matchBulletOrTask`,
    `matchTaskBody`, `toggleTaskMarker`, `toggleTaskBox`) is
    pure-function and would read better in its own
    `MarkdownNotesParser.swift`.
  - `Task/Services/DataImportExport.swift:357-537`
    (`mergeBoard(_:into:plan:)`) is ~180 lines that walk groups,
    tags, and tasks merge in a single method. Extracting
    `mergeGroups`, `mergeTags`, `mergeTasks` would keep future
    plan-adjustment work small and focused.
  - `Task/Views/Settings/AppearanceView.swift` is 487 lines and
    still bundles the `FlatSettingsChoicePicker` family with the
    standalone `ReminderTimePickerSheet` keypad. Splitting the
    keypad sheet into its own file would let `AppearanceView`
    shrink to the picker family it advertises.

- **Naming inconsistencies:**
  - `notesPreviewKey` storage name "task.notesPreviewEnabled" vs the
    stored enum — see N11.
  - `task.activeBoardID` raw UserDefaults key string is still
    referenced at `RootView.swift:10` and `DataImportExport.swift:563`
    with no central constant. Carry-over from archive 04.

- **Structural improvements:**
  - Centralize the `try? context.save()` + `writeSnapshot` pair
    behind a `BoardWriter.save(context:)` helper (~13 snapshot
    callers, ~26 save callers).
  - Move the cross-target color palette into a shared source-only
    file referenced via `PBXFileSystemSynchronizedBuildFileException
    Set` inversions.
  - Make the SwiftUI custom views (`ConfirmationSheet`,
    `SettingsButtonRow`, `SettingsRowLabel`, `SheetActionButtonLabel`,
    the picker sheets) consistent about their string parameter
    type: prefer `LocalizedStringKey` for any user-facing text
    parameter so callsite literals auto-extract and runtime
    rendering localizes.

---

## 4. Functional issues

- **Boards** — Default seed (Personal / Study / Work) covered by
  `testSeedCreatesThreeDefaultBoards`. Add board through the
  switcher works and lands as the active board with empty title /
  subtitle. Board reorder via long-press drag works via the shared
  `ReorderDropDelegate<Board>`. Delete via expanded sheet →
  delete mode → confirmation works; cascades through tasks and
  cancels their notifications. Active-board fallback on delete uses
  the next-remaining board.
- **Board / columns / cards** — Pagination, `.id()` re-render on
  sort change, and pull-to-refresh all work. Card drag-reorder
  correctly no-ops in non-Manual sort modes for same-column moves
  and routes cross-column drops to end-of-list. Watchdog rollback
  re-arms from `dropUpdated` so slow drags don't roll back
  mid-move. The "More · N left" chip renders correctly.
- **Per-task checkbox** — New v0.4.7 affordance. Toggle from the
  card title row (when `showsCheckbox`) and from the editor's
  Checkbox toggle row. Persists. Strikes the card title and dims
  it. Editor's `task.isChecked = showsCheckbox && isChecked` save
  defends against a dangling `isChecked = true` after the user
  hides the checkbox. **Widget never reflects the checkbox state**
  (see N5 / N8).
- **Drag and drop** — Cross-column drops save once via
  `placeTask(commit: true)`. Within-column live drag yields
  smoothly. Drop proposal `.move` everywhere — no green `+` badge.
  Reorder rollback watchdog covers BoardSwitcher / StatusPicker /
  TagPicker via the consolidated `ReorderDropDelegate`.
- **Board date slider** — New v0.4.7 feature. Generates a contiguous
  day window from the union of task-derived dates and the focus
  day, capped to plus/minus one year around today. Recenters on
  open via the `dateFilterOpenToken` and the
  `scrollPosition = nil` then re-assign pattern. Locale uses
  `TaskDateFormat.locale`. Date tile selection toggles the board
  filter.
- **Date filter targeting** — `AppDateFilterTarget` (Working Date
  / Due Date) is a global Settings preference. Covered by
  `testTaskDateFilterCanTargetWorkingRangeOrDueDate`. Working
  Date matches the range *inclusive* of both endpoints; Due Date
  matches the single day.
- **Calendar picker** — Today button works. Range mode after both
  endpoints are set: tapping start swaps end into start and
  clears end; tapping a third date starts a fresh selection.
  Locale: month titles use `TaskDateFormat.locale`.
- **Search** — Cross-board search works; active board surfaces
  first.
- **Default Status picker** — Default Status is set via the Default
  for New Tasks toggle inside the per-group **Edit Status** sheet
  (`GroupMenuSheet`). New-task sheet uses `board.defaultGroup`
  which falls back to `orderedGroups.first`. "Current default:
  …" line uses `String(localized: "None")` for empty fallback.
- **Status / Tag picker management** — Done via `StatusPickerSheet`
  and `TagPickerSheet`. Both use the consolidated
  `ReorderDropDelegate`. Swipe-left to reveal Edit. Delete-mode
  toggle is consistent across both. Both compute `sheetTitle: String`
  — see N3 (navigation title doesn't localize on Chinese builds).
- **Task editor** — Title field uses `TextField(prompt:)`. Seven
  property rows (Status / Tags / Working / Due / Repeat / Checkbox
  / Reminder). New checkbox row toggles `showsCheckbox`. Reminder
  anchor badge mirrors `TaskItem.primaryReminderDate`. Repeat
  advance `→` shifts every set date forward by one occurrence
  (accessibility label says "Reset to next occurrence" — see N7).
  Duplicate Task action via the bottom row + `ConfirmationSheet`.
  Save's "past fire time today" branch shows an inline warning
  before save so the silent clear isn't a surprise.
- **Repeat options** — v0.4.7 added biweekly, quarterly, and
  annually. Covered by `testBiweeklyRepeatAdvancesByTwoWeeks` and
  `testQuarterlyAndAnnuallyRepeatAdvanceByExpectedIntervals`.
- **Markdown notes** — `MarkdownNotesEditor` supports headings,
  bold, italic, bullets, checklists with all four prefix shapes
  (`- [ ]`, `- []`, `[ ]`, `[]`, plus checked variants), and live
  styling while editing. Editor focus toggles between
  raw-with-styling view and the parsed preview. Preview supports
  tap-to-edit.
- **Card notes preview** — Driven by `settings.notesPreview`
  enum; shows 0/1/2/3 lines depending on the setting.
  `cardNotesPreviewLines` parses the same shapes as the editor.
- **Import / Export / Reset** — Round-trips correctly for self-
  exported data. `showsCheckbox` and `isChecked` are round-tripped
  in `TaskExport` with `decodeIfPresent` for backward-compat
  (covered by `testTaskExportDecodesCheckboxFieldsAndDefaultsLegacyPayloadsToOff`).
  Orphan counts surface via inflection markup. Reset shows a
  `ProgressOverlay` and yields every 50 tasks during the
  cancellation loop.
- **Notifications** — Past-date guard skips occurrences before
  now. Authorization-denied state surfaces a banner. Reminder is
  auto-disabled when the user clears the last date. Repeat is
  batched as 16 one-shots and refreshed on app launch /
  scene-active via `RootView.refreshRepeatReminders`. Time-of-day
  is read from the per-board `reminderMinutesOfDay` at schedule
  time. Reminder Time changes re-schedule existing reminders
  asynchronously.
- **Storage Check (new)** — `SettingsView.checkStorage()` calls
  `DataImportExport.storageSummary(context:)` which fetches each
  model type, encodes a `MultiBoardExportPayload` to estimate
  bytes, and renders the result inline. Row labels "Storage
  Check" / "Tap to check" / "Checking..." are not localized on
  Chinese builds (see N2).
- **Widget board filter** — Works. Filtering by board reads
  `entry.boardID == config.board?.id`.
- **Widget status filter (new)** — Works for valid combinations
  but allows mismatched board + status picks that filter
  everything out (see N6). UI shows the board emoji as a row
  badge when "All Boards" is configured.
- **Widget background style (new)** — Three options (System
  Default / Pure Black / Pure White) wired through
  `BoardConfigurationIntent.background`.
- **Localization** — Catalog covers 196 / 273 keys in zh-Hans
  (active), 77 stale. The `testStringCatalogHasTranslatedZhHansForActiveKeys`
  test gates non-stale keys but does not flag user-visible
  strings that bypass extraction entirely (N1 / N2 / N3).
- **Widget localization** — Widget target has no catalog (N4).

---

## 5. UI/UX issues

- **N1 (ConfirmationSheet)** — Every destructive confirmation
  renders title/message/buttons in English on Chinese builds.
- **N2 (Settings rows)** — Settings row titles render English on
  Chinese builds while their values render Chinese; visible
  mismatch on most rows.
- **N3 (Picker sheet titles)** — Status and Tag picker navigation
  bars render English titles on Chinese builds.
- **N4 (Widget extension catalog)** — Widget renders English on
  Chinese builds regardless of user language preference.
- **N5 (Widget reflects checkbox state)** — Checked task still
  shows up unchanged on the widget.
- **N6 (Widget status filter dead-end)** — Cross-board status
  selection results in "No upcoming" forever.
- **N7 (Repeat advance accessibility label)** — VoiceOver users
  hear "Reset to next occurrence" for a forward-shift action.
- **N9 (Repeat picker task count plural)** — "1 tasks" / "0 tasks"
  in English.
- **N11 (notesPreviewKey rename)** — purely cosmetic; the key name
  carries an `Enabled` suffix while the stored value is the
  `AppNotesPreview` enum's raw value. No user-facing impact.
- **Drag preview shapes** — All card surfaces use
  `.contentShape(.dragPreview, RoundedRectangle(cornerRadius: …))`
  / `Capsule(...)` for the group pill. No green `+` anywhere.
- **iOS 26 fallback parity** — `BottomNavBar` forks via
  `#available(iOS 26.0, *)`; the iOS 18-25 fallback uses
  `.thinMaterial` + `secondarySystemBackground` circles with the
  same control set.
- **ConfirmationSheet fixed height** — `confirmationSheetPresentationStyle()`
  pins the detent to 360 pt. The Reset confirmation copy is the
  longest message anywhere; at very large Dynamic Type sizes it
  could press against the buttons. Not currently observed; flag
  for on-device verification.
- **MarkdownNotesEditor blank-line tap target** — `Color.clear`
  with `frame(height: 8)` and `onTapGesture { beginEditing() }`.
  Narrow hit target; carries over from prior audits.
- **`ProjectHeaderView` icon button asymmetry** — Sort icon stays
  neutral even when sort is not Manual. Date Filter icon tints
  when the filter is active. Minor consistency issue.

---

## 6. Data and persistence issues

- **Cascade deletes** — `Board.groups` / `tags` / `tasks` all set
  `deleteRule: .cascade`. `BoardGroup.tasks` uses `.nullify`.
  Live delete paths reassign tasks to the fallback group before
  deleting; the cascade-from-Board path deletes everything anyway,
  so no orphan.
- **CloudKit-readiness invariants** — Every `@Model` property in
  `Board`, `BoardGroup`, `TaskTag`, `TaskItem` has a default value,
  no `@Attribute(.unique)`, optional inverse relationships. New
  `showsCheckbox` / `isChecked` properties also default-`false`,
  so SwiftData lightweight migration handles the v0.4.7 upgrade.
- **`TaskItem.duplicated(sortIndex:)`** copies every editable
  field including `showsCheckbox` and `isChecked`. Tested by
  `testTaskDuplicateCopiesEditableFieldsAndRelationships`. Should
  it really copy `isChecked = true` to the duplicate, given the
  duplicate is a brand-new task? Probably; the user just hit
  "duplicate" on a task they may have already finished and wants
  to start over — but the duplicate inherits the "done" state.
  Worth a UX call.
- **In-memory fallback signal** — `RootView` surfaces the alert
  exactly once per launch. `resetAll` purges the on-disk store
  files when in fallback so the next launch can rebuild cleanly.
- **Snapshot encoding** — Both write paths use `.iso8601`; widget
  decoder matches. App-side and widget-side entry types
  differ in optionality on purpose (older snapshots).
- **`writeBoardList` / `writeStatusList` use default JSONEncoder()**
  — `SharedDefaultsService.swift:67-72,83-88`. Neither entry type
  carries `Date` fields today so this is benign; if any are added,
  mirror the `.iso8601` rule.
- **Export ordering** — `BoardExportEntry.tasks` are written in
  natural `(board.tasks ?? [])` order; round-trip still works
  because `sortIndex` is persisted, but exports are not
  byte-identical across runs.
- **Save-failure paths** — `TaskDetailView.save / delete /
  duplicate` and `DataImportExport.importData` all `try
  context.save()` with `rollback()` on failure. Good defense.
- **`task.activeBoardID` UserDefaults key** — still not
  centralized; see §3 naming inconsistencies.

---

## 7. Configuration and platform issues

- **Version drift** — `README.md`, `VersionHistory.md`, and
  `task.xcodeproj/project.pbxproj` all agree at `0.4.7 (build 5)`.
- **Signing** — `Config/Signing.xcconfig` with the optional
  `Signing.local.xcconfig` override documented in README. Each
  Task / TaskWidgetExtension config references it via
  `baseConfigurationReference`.
- **iOS deployment target 18.0** on all four targets. `#available
  (iOS 26.0, *)` paths in `BottomNavBar` remain the only forks.
- **App Group `group.com.ijustin.task`** is configured on both
  `Task.entitlements` and `TaskWidgetExtension.entitlements`.
- **Privacy manifests** — Both `Task/PrivacyInfo.xcprivacy` and
  `TaskWidgetExtension/PrivacyInfo.xcprivacy` declare
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
- **Widget localization (N4)** — No `Localizable.xcstrings` in
  the widget target's source tree. Project setting / file layout
  change needed.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  remains excluded; everything else under the synchronized roots
  picks up its target automatically.
- **Alternate icons** —
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet
  Midnight Neutral Light"` matches `AppIconOption.alternateName`.
- **Swift 5.0** — pinned in every target's `SWIFT_VERSION`.
- **Portrait-only, iPhone-only** — unchanged.

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - Widget snapshot round-trip including the new optional
    `groupID` / `groupSortIndex` / `boardID` / `boardEmoji` /
    `boardTitle` fields, and the legacy decode path (older
    snapshots without those fields).
  - Widget filter logic — `UpcomingTasksProvider.filter(_:by:)`
    has the N6 cross-board mismatch behavior. A unit test that
    constructs a snapshot with two boards, configures the
    intent to a board + a different-board status, and asserts
    the result is empty would lock in the current behavior so
    the fix can be tested explicitly.
  - Snapshot-write side effects — assert that
    `UpcomingSnapshotBuilder.writeSnapshot` is *not* a
    measurable cost on board-card checkbox toggles once N5/N8
    are addressed (or alternatively that the snapshot now
    reflects `isChecked`).
  - `TaskItem.duplicated(sortIndex:)` — current test asserts
    fields copy. A complementary test could check that the
    duplicate's `isChecked` starts `false` if that's the
    decided behavior.
  - `ConfirmationSheet` and `SettingsButtonRow` /
    `SettingsRowLabel` — once N1/N2/N3 are fixed, add tests
    that verify localized strings render correctly via the
    catalog (snapshot or pixel diff).
  - `NotificationService.schedule` for the new repeat options
    (`.biweekly`, `.quarterly`, `.annually`) — assert that the
    repeat batch advances by the expected calendar component.
  - `RootView.refreshRepeatReminders` on scene-active for the
    new repeat options — schedule a quarterly reminder whose
    batch has only 3 occurrences left and assert the next batch
    lays down a fresh 16 starting from the next future
    occurrence.
  - Widget extension localization — a unit test that
    instantiates the widget view and asserts the rendered text
    matches the catalog at zh-Hans (once N4 ships).

- **Suggested tests:**
  - `testConfirmationSheetUsesLocalizedTextWhenLanguageIsChinese()`
    — after N1, force `settings.language = .simplifiedChinese`,
    render a delete confirmation, assert the text contains
    `"删除"` not `"Delete"`. Snapshot test or string-extract
    test.
  - `testWidgetStatusFilterReturnsEmptyForCrossBoardSelection()`
    — locks in current N6 behavior so any fix can be verified.
  - `testWidgetSnapshotExcludesCheckedTasks()` — after N5, write a
    snapshot from a board with two tasks (one checked, one not),
    assert only the unchecked task is in the snapshot.
  - `testRepeatBatchSchedulesSixteenTriggersForQuarterly()` /
    `testRepeatBatchSchedulesSixteenTriggersForAnnually()` —
    extend the existing tests to the new repeat options.

- **Manual / device-only:**
  - Verify the widget refreshes promptly after task edits in a
    real widget install across all three families.
  - Confirm `setAlternateIconName` actually swaps app icons on
    iOS 18 and iOS 26.
  - VoiceOver pass over the new bottom action clusters (Delete
    Task + Duplicate Task; Delete a Status + Add a Status;
    Delete a Tag + Add a Tag), the swipe-to-edit action on
    rows, the date slider tiles, and the Markdown checkbox
    rows.
  - Reproduce N1 / N2 / N3: switch the app to Chinese, open
    each affected sheet, confirm whether the text matches the
    proposed catalog lookups.
  - Reproduce N4: install the widget on a Chinese-language
    device, confirm the strings render in English.
  - Reproduce N5: toggle a checkbox on the board, verify the
    widget still shows the task unchanged.
  - Reproduce N6: configure the widget with a board and a
    status from a different board, verify "No upcoming" persists.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — Change `ConfirmationSheet`'s four user-facing
    parameters to `LocalizedStringKey`. Largest user-visible
    localization gap; touches one component file.
  - **N2** — Change `SettingsButtonRow.title` and
    `SettingsRowLabel.title` (and optionally `value`) to
    `LocalizedStringKey`; add the three missing Settings → Board
    row keys (`Date Filter`, `Date Format`, `Notes Preview`) plus
    their zh-Hans translations.
  - **N3** — Change `StatusPickerSheet.sheetTitle` and
    `TagPickerSheet.sheetTitle` to return `LocalizedStringKey`.
    One-line edit each.
- **Fix next:**
  - **N4** — Add a widget-target `Localizable.xcstrings` (or
    share the app's via a synchronized-folder inversion) and
    translate the small fixed widget-string set.
  - **N5** — Decide widget behavior for checked tasks (hide or
    visually de-emphasize); plumb the field or filter. Pairs
    naturally with **N8**.
  - **N6** — Constrain `StatusEntityQuery` to the currently-
    selected `BoardEntity` using AppIntents' parameter
    dependencies, or surface a clear "no matching tasks"
    hint in the widget.
- **Optional cleanup:**
  - **N7** — Rename the repeat-advance accessibility label from
    "Reset to next occurrence" to "Advance to next occurrence".
  - **N9** — Apply inflection markup to the repeat picker's
    `"%lld tasks"` row count.
  - **N10** — Run a one-shot pruning pass over
    `Task/Localizable.xcstrings` after N1-N4 land.
  - **N11** — Optional cosmetic rename of `task.notesPreviewEnabled`
    to a name that matches its enum storage; only if combined with
    a dual-read migration so existing user preferences aren't
    dropped.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- `docs/Issues-cc-04.md` cross-referenced against current code for
  every prior issue. N1-N14 from archive 04 confirmed resolved:
  all 7 zh-Hans keys translated (catalog test passes), `GroupMenuSheet`
  uses `String(localized: "None")`, `TimeFormatting`/`ReminderTimePickerSheet`
  use `String(localized: "AM"/"PM")`, all four `Date.formatted`
  callsites pass `.locale(TaskDateFormat.locale)`, `MarkdownNotesEditor`
  defaults the placeholder to `String(localized: "Add notes")`,
  `TaskDetailView` shows an inline warning for the past-fire-date
  case, `TagPickerSheet.addTag` mirrors `StatusPickerSheet.addGroup`,
  `CardOrderPickerSheet`'s Cancel is gone, README and pbxproj agree
  on build 5, bare `TaskDateFormat.format(_:)` overloads removed,
  `rescheduleReminders` is async with `Task.yield`, `groupDragPrefix`
  is file-scope, and the two `Issues-cx/gg` files live under `docs/`.
- `docs/Issues-cc-03.md` cross-referenced for archive-level
  carryovers.
- All Swift sources under `Task/`:
  - Models (`Board`, `BoardGroup`, `TaskTag`, `TaskItem`, `ColorKey`,
    `RepeatRule` with the new biweekly/quarterly/annually cases).
    `TaskItem` gained `showsCheckbox`/`isChecked` and its
    `duplicated(sortIndex:)` copies them.
  - Services (`SwiftDataManager`, `NotificationService`,
    `SharedDefaultsService` with the new
    `groupID`/`groupSortIndex`/`groupName`/`groupColorKey` snapshot
    fields and the new `StatusListEntry`,
    `UpcomingSnapshotBuilder` with the new `statusListEntries` and
    `sortedEntries`, `DataImportExport` with checkbox round-trip,
    storage summary, and the v2 wire format with `showsCheckbox`/
    `isChecked` `decodeIfPresent`-d).
  - Utils (`AppInfo`, `DateFormatters`).
  - ViewModels (`SettingsViewModel`) with the new
    `AppDateFilterTarget` and `AppNotesPreview` enums.
  - Views: `RootView`, board (`BoardView` + `BoardDateSlider` +
    `BoardDateSliderDayWindow`, `BoardSwitcherView`, `ColumnView`,
    `GroupMenuSheet`, `ProjectHeaderView`, `TaskCardView` with the
    new checkbox row, `BoardIconPickerSheet`), task (`TaskDetailView`
    with the new Checkbox row + inline reminder warning,
    `MarkdownNotesEditor` + `LiveMarkdownTextView`,
    `RepeatPickerSheet` with the new chip rows, `StatusPickerSheet`
    and `TagPickerSheet` with swipe-to-edit and the consolidated
    `ReorderDropDelegate`), search (`SearchView`), settings
    (`SettingsView` with the new Date Filter / Date Format / Notes
    Preview / Reminder Time / Storage Check rows, `AppearanceView`
    + `ReminderTimePickerSheet`, `CardOrderPickerSheet`,
    `IconPickerSheet`, `ManualControlSheet`, `AboutSheets`).
  - Components (`BottomNavBar`, `CalendarPicker`, `CardBackground`,
    `ColorSwatchPicker`, `ConfirmationSheet`, `DateRow`, `FlowLayout`,
    `GridTile`, `GroupHeaderPill`, `ProgressOverlay`,
    `ReorderDropDelegate`, `SettingsCard` including
    `SheetActionButtonLabel`, `StringMoveDropDelegate`, `TagChip`).
- All Swift sources under `TaskWidgetExtension/`
  (`TaskWidgetBundle`, `UpcomingTasksProvider`, `UpcomingTasksWidget`
  with the new background-style widget modifier, `WidgetSnapshot`
  with the new `groupID`/`groupSortIndex` fields and
  `WidgetStatusListEntry`, `BoardConfigurationIntent` with the new
  `status` and `background` parameters).
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/Info.plist`.
- `Config/Signing.xcconfig` and `task.xcodeproj/project.pbxproj`
  — build settings, synchronized folder exceptions, code signing,
  marketing / current version, INFOPLIST keys, bundle IDs, asset
  catalog config.
- `Task/Localizable.xcstrings` — programmatic count of total keys
  (273), active (196), stale (77), zh-Hans `state: "translated"`
  (196 active = 100%). Specific keys probed: `Choose Status`,
  `Choose Tags`, `Delete Status`, `Delete Tag`, `Delete Board`,
  `Choose Repeat`, `New Task`, `Edit Task`, `Untitled`, `Upcoming`,
  `No upcoming`, `No upcoming tasks`, `iCloud Sync`, `Coming Soon`,
  `Manual Control`, `Storage Check`, `Theme`, `Language`,
  `Time Format`, `Reminder Time`, `Date Filter`, `Date Format`,
  `Notes Preview`, `Version`, `%lld tasks`, `%lld upcoming`,
  `Delete Task?`, `Duplicate Task?`, `This task and any reminder
  you set will be removed permanently.`, `A copy of this task will
  be created in the same status.`, `Reset to next occurrence`.
- `TaskTests/TaskTests.swift` (22 tests, including the new
  `testTaskExportDecodesCheckboxFieldsAndDefaultsLegacyPayloadsToOff`,
  `testStorageSummaryCountsAppDataModelsAndExportBytes`,
  `testBiweeklyRepeatAdvancesByTwoWeeks`,
  `testQuarterlyAndAnnuallyRepeatAdvanceByExpectedIntervals`,
  `testUpcomingSnapshotSortPrioritizesStatusOrderBeforeDate`,
  `testWidgetStatusListUsesBoardAndStatusOrder`).
- Grep queries (via `grep -rn ... --include='*.swift'`):
  - `TODO|FIXME|XXX` (no production matches).
  - `try!|as!|implicitlyUnwrapped` (only a comment in
    `SwiftDataManager`; no production force-unwraps).
  - `print(` (no production matches).
  - `TaskDateFormat.format|TaskDateFormat.locale|TaskDateFormat.currentStyle`
    (verifying archive 04 N5/N11 fixes).
  - `"AM"|"PM"|"AM/PM"` (verifying archive 04 N3/N4 fixes).
  - `try? context.save()` (26 callsites).
  - `UpcomingSnapshotBuilder.writeSnapshot` (15 callsites).
  - `navigationTitle` (all callsites surveyed; surfaced N3).
  - `SheetActionButtonLabel|SettingsButtonRow|SettingsRowLabel`
    (verifying parameter types; surfaced N2).
  - `ConfirmationSheet|confirmLabel` (verifying parameter types;
    surfaced N1).
  - `"Untitled"|"Upcoming"|"No upcoming"|String(localized:` in
    `TaskWidgetExtension/` (surfaced N4).
  - `MARKETING_VERSION|CURRENT_PROJECT_VERSION` in pbxproj
    (verifying archive 04 N10 fix).

## Not checked (worth a follow-up)

- Live runtime behavior on iOS 18.x vs iOS 26 devices /
  simulators (Liquid Glass parity, alternate icon transitions,
  drag previews, the new board date slider scroll-position
  recentering on dataset changes, ConfirmationSheet copy at
  extreme Dynamic Type sizes).
- On-device notification delivery, authorization-denied paths,
  and notification body composition in different locales —
  particularly the repeat-batch refresh on scene-active for the
  new biweekly/quarterly/annually rules.
- Instruments / memory profile for a board with thousands of
  tasks; the new Storage Check row's
  `DataImportExport.exportData` round trip cost; the cost of
  re-encoding the export-bytes summary just to display a file
  size.
- Widget rendering under each `WidgetFamily` on a real device,
  the configuration intent picker after a board rename / icon
  change, and the new `WidgetBackgroundStyle` options.
- Asset catalog contents — that the alternate icons
  (`Rose/Violet/Midnight/Neutral/Light`) and their `*Preview`
  siblings actually exist; the catalog isn't part of this audit.
- Verification that `Text(stringVar)` for a `String`-typed
  variable bypasses catalog lookup in the current SwiftUI
  runtime (this audit reasons from documented behavior but does
  not execute the app on a Chinese-locale device to confirm).
  All of N1 / N2 / N3 carry an implicit `Needs verification`
  caveat for that reason.
- Accessibility audit (Dynamic Type extremes, VoiceOver labels
  beyond N7, hit targets, drag-and-drop accessibility).
- `TestData/testdata.json` integrity — not diff-walked.
