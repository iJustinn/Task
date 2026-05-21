# Task — Issues Report

Audit of branch `task-v0.4.5` on 2026-05-21. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.4.5 (build 1) is healthy overall. Most of the prior audit's
findings (N1, N2, N3, N4, N5, N7, N8, N12, N13, N14, N15 from
`docs/IssuesArchive-01.md`) are resolved. The 0.4.0 multi-board rewrite
introduced clean per-board state and a new widget configuration intent.
The biggest risks today are: (a) the **Default Status** picker regressed
in 0.4.5 — `DefaultStatusPickerSheet` is defined but no view ever opens
it, so users can no longer choose which group new tasks land in; (b) two
settings views (`ManageGroupsView`, `ManageTagsView`) are orphaned for
the same reason; (c) `HowToUseSheet` documents UI paths
("Settings > Customization > Groups/Tags", "Settings > Default > Status")
that no longer exist; (d) `Reset All Data` copy still references "six
default groups" from v0.1.0 (current seed is five per board across three
boards). Several Medium items are quality-of-life: date formatters
ignore the user's chosen `AppLanguage`, the localization catalog is 58%
unfilled for Simplified Chinese, the reset flow shows no progress
overlay, and `BoardIconPickerSheet`'s `Cancel` button is a no-op since
selection is auto-committed. Areas reviewed: models, services, view
models, all views (board, board switcher, task detail, search, settings,
customization, about, components), widget target, project configuration,
entitlements, privacy info, and `Localizable.xcstrings` coverage. Not
reviewed: live runtime behavior on device, on-device notification
delivery, Instruments traces, asset catalog contents.

---

## 2. Issue list

### N1. `DefaultStatusPickerSheet` is unreachable — Default Status feature is regressed

- **Severity:** High
- **Related files:** `Task/Views/Settings/DefaultStatusPickerSheet.swift:1-55`,
  `Task/Views/Board/ProjectHeaderView.swift:44-51`,
  `Task/Views/Settings/SettingsView.swift:138-205`,
  `Task/Models/Board.swift:14,46-53`,
  `Task/Views/RootView.swift:77-79`
- **Description:** `DefaultStatusPickerSheet` is defined and writes
  `board.defaultGroupID`, but no view in the app ever instantiates it.
  `grep -rn 'DefaultStatusPickerSheet' --include='*.swift'` returns only
  the file's own `struct` declaration. The `ProjectHeaderView` toolbar
  exposes Sort (`CardOrderPickerSheet`) and Reminder Time
  (`ReminderTimePickerSheet`) icons but no Default Status icon. The
  Settings screen also has no Default Status row. `Board.defaultGroup`
  therefore always falls back to `orderedGroups.first` (line 52). In
  0.3.x there was a `Settings > Default > Status` row that opened this
  picker — that row was removed in the 0.4.5 rewrite without a
  replacement entry point.
- **Why it matters:** Visible feature regression. Users who picked a
  non-first default in 0.3.x lost the affordance to change it; new users
  cannot configure it at all. New tasks always land in the first group
  on the board.
- **Suggested fix:** Either (a) add a third icon button in
  `ProjectHeaderView` (next to Sort and Reminder Time) that opens
  `DefaultStatusPickerSheet(board: board)`; or (b) restore the Settings
  row that opens it. Option (a) is more consistent with where the other
  per-board pickers live now.
- **Risks / dependencies:** None. The sheet itself is correctly
  implemented and the data path already works through the legacy
  migration.

### N2. `HowToUseSheet` documents UI paths that no longer exist

- **Severity:** High
- **Related files:** `Task/Views/Settings/AboutSheets.swift:115,144-146,174-177`
- **Description:** Three sections of the How to Use sheet point users to
  paths that the current Settings layout does not expose:
  - Line 115: "New tasks open in the active board's default Status
    (Settings > Default > Status)" — that row does not exist (see N1).
  - Line 144: "Settings > Customization > Groups manages the active
    board's groups…" — the Customization section was removed in 0.4.0;
    `ManageGroupsView` is no longer reachable (see N3).
  - Line 145: "Settings > Customization > Tags manages tags…" — same.
  - Line 174-177: "Settings > Default is scoped to the active board —
    each board remembers its own default Status, Card Order, and
    Reminder Time." — Card Order and Reminder Time are reachable from
    the board header (`ProjectHeaderView`), but the wording implies a
    Settings location; Status is not reachable at all (N1).
- **Why it matters:** First-run users follow these breadcrumbs, can't
  find the paths, and conclude the docs are stale (or the feature is
  broken). Compounds the regression in N1.
- **Suggested fix:** Rewrite the affected `steps:` strings to describe
  the actual gestures: long-press a group's `…` menu on the column for
  group management; tap the trash zone in `TagPickerSheet` to delete a
  tag; tap the Sort / Reminder icons in the board header for those
  pickers. If N1 is fixed by adding a Default Status button, document
  it in the same place.
- **Risks / dependencies:** None. Docs change only.

### N3. `ManageGroupsView` and `ManageTagsView` are orphan files

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/ManageGroupsView.swift:1-213`,
  `Task/Views/Settings/ManageTagsView.swift:1-321`
- **Description:** Both views are defined with full implementations
  (drag-reorder, edit sheets, add/delete flows) but no other file
  references them. `grep -rn 'ManageGroupsView\|ManageTagsView'
  --include='*.swift'` finds only the `struct` definitions and the
  stale `HowToUseSheet` references (N2). The 0.4.0 multi-board work
  moved group editing to the column header's `…` menu (`GroupMenuSheet`)
  and tag editing into `TagPickerSheet`; the two `Manage*View`s were
  left behind. Each is ~200 lines of dead code that has to be kept
  compiling.
- **Why it matters:** Maintenance burden, false discoverability for
  contributors, drift risk between the live editing surfaces and the
  unreachable ones.
- **Suggested fix:** Pick one path:
  - Delete both files (plus the `TagEditSheet` struct inside
    `ManageTagsView.swift:233-320`) since their behavior is fully
    covered by the live surfaces.
  - Or restore Settings rows that present them as a power-user "manage
    everything in this board" entry point (would also be a place to
    expose Default Status; see N1).
- **Risks / dependencies:** If deleting, double-check there are no
  references in test plans or future planning docs (the live grep
  showed none).

### N4. `Reset All Data` copy still says "six default groups" but the seed is five per board

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/ManualControlSheet.swift:62-65`,
  `Task/Services/SwiftDataManager.swift:40-44,74-80`
- **Description:** The confirmation sheet message reads "This will
  delete every group, tag, and task, then restore the six default
  groups. This can't be undone." Two problems with this copy in 0.4.5:
  1. The default seed is **three boards** × **five groups** (Waiting,
     Doing, Pending, Done, Archive), not six groups. The "six" comes
     from v0.1.0's single-board seed (Daily, Weekly, Waiting, Doing,
     Pending, Done).
  2. The sentence omits that boards are also deleted/re-seeded — a
     user might think only groups are restored, but `resetAll` deletes
     every `Board` and then re-seeds the three defaults.
- **Why it matters:** Users may be misled about what Reset does and
  what they get back. Important when the action is destructive and
  irreversible.
- **Suggested fix:** Replace with: "This will delete every board,
  group, tag, and task on this device, then restore the three default
  boards (Personal, Study, Work) with five groups each. This can't be
  undone."
- **Risks / dependencies:** None. Copy only; if changed, also pass
  through `Localizable.xcstrings`.

### N5. `BoardIconPickerSheet` Cancel does nothing — selection auto-commits on tap

- **Severity:** Medium
- **Related files:** `Task/Views/Board/BoardIconPickerSheet.swift:27-50`,
  `Task/Views/Board/ProjectHeaderView.swift:70-79`
- **Description:** Tapping an emoji tile fires `onSelect(emoji)` and
  immediately dismisses (lines 28-30); the caller writes `iconEmoji`,
  saves, and updates the widget snapshot synchronously. The toolbar
  then exposes both a leading `Cancel` and a trailing `Done` (lines
  44-51) that just call `dismiss()`. By the time the user taps Cancel,
  the change is already persisted. The Cancel button is misleading.
- **Why it matters:** "Cancel" in iOS implies undo. A user who taps
  the wrong emoji and reaches for Cancel will assume their prior icon
  is restored — it isn't. The same anti-pattern existed in 0.2.0
  picker sheets and was raised under prior N11.
- **Suggested fix:** Two clean options:
  - (a) Remove the auto-commit on tap; track a `pendingIcon` and only
    call `onSelect` on `Done`. Make Cancel actually cancel.
  - (b) Drop the Cancel button; keep only Done so the toolbar matches
    the "tap-to-commit" semantics (same as ThemePickerSheet,
    AccentPickerSheet, etc., which all commit on tile tap).
- **Risks / dependencies:** Option (a) is the more surprising-but-
  correct behavior. Option (b) is consistent with the rest of the
  picker family and is the smaller patch.

### N6. `DateFormatters` ignore `settings.language.locale`

- **Severity:** Medium
- **Related files:** `Task/Utils/DateFormatters.swift:4-16`,
  `Task/TaskApp.swift:16`,
  `Task/Models/TaskItem.swift`, `Task/Components/DateRow.swift`,
  `Task/Views/Task/TaskDetailView.swift`
- **Description:** `TaskDateFormat.medium` is a `DateFormatter`
  singleton initialized without an explicit `locale`, so it uses
  `Locale.autoupdatingCurrent` — i.e. the **device** locale. The app
  separately injects `settings.language.locale` via
  `.environment(\.locale, …)` (TaskApp.swift:16), but
  `DateFormatter.string(from:)` doesn't read environment values. A
  Chinese-device user who selects English in Settings sees English
  labels but **Chinese dates** on cards, task detail, search results,
  and notifications. Conversely, an English-device user who selects
  Simplified Chinese keeps English dates.
- **Why it matters:** Mismatched language between UI text and dates
  is obvious to bilingual users and undermines the language picker.
- **Suggested fix:** Either (a) compute formatters lazily per-render
  using the current environment locale (e.g. a SwiftUI `EnvironmentKey`
  injecting a configured formatter), or (b) expose a `setLocale(_:)` on
  `TaskDateFormat` that `SettingsViewModel.language.didSet` calls so the
  singleton re-anchors to the chosen locale.
- **Risks / dependencies:** Singleton mutation needs a `@MainActor`
  guard (or a per-call formatter); shouldn't affect notifications since
  `NotificationService.dateSummary` runs in the same process.

### N7. Reset All Data shows no progress overlay even though it's async

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/SettingsView.swift:434-438`,
  `Task/Views/Settings/ManualControlSheet.swift:104-130`,
  `Task/Services/DataImportExport.swift:432-448`
- **Description:** `DataImportExport.resetAll` deletes every task
  (each one cancelling its pending notification), then every board
  (cascading to groups and tags), then re-seeds. It yields every 50
  tasks to give the UI a chance to repaint, but the caller
  (`performReset` → `dismissThenRun(onReset)`) does not toggle any
  `isResetting` state, so the `ProgressOverlay` never appears. On a
  board freshly imported from `TestData/testdata.json` (~375 tasks),
  this can feel like a hang.
- **Why it matters:** Apparent app freeze after a destructive
  confirmation. The user just tapped "Reset All Data"; silence is the
  worst response.
- **Suggested fix:** Mirror the import flow: add an
  `@State var isResetting = false`, flip it to `true` before awaiting
  `resetAll`, render a `ProgressOverlay(title: "Resetting Data",
  message: "Restoring default boards…")`, and flip it back when the
  await returns. Reuse the same animation as `isImporting`.
- **Risks / dependencies:** None. Cosmetic + a small state field.

### N8. `iCloud Sync` row still looks tappable but isn't

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/SettingsView.swift:217-222`
- **Description:** The iCloud Sync row uses `SettingsRowLabel` with
  `value: "Coming Soon"` and no `accessory:` (so no chevron and no
  toggle). It sits between identically-styled `SettingsButtonRow`s in
  the Data section. Same tile size, same icon, same row height — the
  only signal that it's not interactive is the absent chevron, which is
  easy to miss. Identical situation to N10 in the prior audit, still
  unresolved.
- **Why it matters:** Discoverability — users will tap it expecting a
  "what's this" sheet or a sign-up flow and get nothing.
- **Suggested fix:** Either (a) convert it to a `SettingsButtonRow`
  that opens a small `ComingSoonSheet` explaining the roadmap (the
  schema is already CloudKit-ready per LessonsLearned), or (b) dim
  the title (`.foregroundColor(.secondary)`) so the disabled state is
  obvious.
- **Risks / dependencies:** None.

### N9. Sheet toolbar conventions are still inconsistent across the app

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/SettingsView.swift:65-68`
  (Done only), `Task/Views/Board/BoardSwitcherView.swift:79-84`
  ("Close" + "Add"), `Task/Views/Settings/AboutSheets.swift:228-235`
  (Cancel + Done that both `dismiss()`), `Task/Views/Settings/ManualControlSheet.swift:53-57`
  (Done only), `Task/Views/Settings/AboutSheets.swift:273-278`
  (Feedback: Done only), `Task/Views/Board/BoardIconPickerSheet.swift:44-51`
  (Cancel + Done both `dismiss()` — see also N5)
- **Description:** Per LessonsLearned the rule is supposed to be
  `Cancel` (top-leading) + `Done` (top-trailing), with both calling
  `dismiss()` for info sheets. Current state:
  - SettingsView: Done only.
  - BoardSwitcherView: "Close" + "Add" — uses "Close" instead of
    "Cancel" and "Add" instead of "Done".
  - HowToUseSheet, PrivacySheet, DisclaimerSheet, CopyrightSheet:
    Cancel + Done (both `dismiss()`).
  - FeedbackSheet, ManualControlSheet: Done only.
  - BoardIconPickerSheet: Cancel + Done (both `dismiss()` — but
    selection is already committed; see N5).
  - GroupMenuSheet, TagEditSheet (orphan, see N3): Cancel + Save.
  - StatusPickerSheet, TagPickerSheet, picker family in
    AppearanceView.swift: Cancel + Done.
  Several patterns coexist with no clear rule.
- **Why it matters:** Cumulative inconsistency dents perceived
  polish; users navigating from one sheet to the next see the
  trailing button change role and label.
- **Suggested fix:** Codify the rule:
  - "Info-only" sheets (Privacy, Disclaimer, Copyright, HowToUse,
    Feedback, ManualControl, Settings): trailing `Done` only — no
    leading button (the sheet has nothing to cancel).
  - "Edit" sheets (GroupMenu, TagEdit, etc.): `Cancel` + `Save`.
  - "Picker" sheets (Status, Tag, Theme, etc.): `Cancel` + `Done`
    where Cancel actually reverts (or single-tap-to-commit sheets:
    `Done` only).
  - BoardSwitcher: rename "Close" to "Done" and keep "Add" as a
    separate trailing item.
- **Risks / dependencies:** Touches many files but each change is
  small.

### N10. Localizable.xcstrings is 42% translated for Simplified Chinese

- **Severity:** Medium
- **Related files:** `Task/Localizable.xcstrings`
- **Description:** `python3 json.load` reports 203 keys total with 85
  in `state: "translated"` for `zh-Hans` — 118 keys (58%) are missing
  zh-Hans translations and fall back to the English source string.
  Many user-visible strings — `"Edit Task"`, `"Reset to next
  occurrence"`, `"Order doesn't apply to Manual — drag a card to
  reorder it inside its group."`, `"Drag here to delete"`, every
  About-sheet `steps:` line, every alert title/body in
  SettingsView.swift:103-131 — are unlocalized.
- **Why it matters:** A user who picks 简体中文 in the language picker
  still sees English mixed into the UI everywhere, which contradicts
  the language picker and harms the perceived completeness of the
  Chinese build.
- **Suggested fix:** A focused translation pass before the next
  Chinese-targeted release. The catalog is auto-extracted on build
  (`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`), so translators just
  need to fill in the zh-Hans column.
- **Risks / dependencies:** None for the translation itself. A
  follow-up pass would be needed any time copy changes (e.g. the
  rewrites called out in N2 and N4).

### N11. Notifications scheduled without authorization fail silently

- **Severity:** Medium
- **Related files:** `Task/Services/NotificationService.swift:5-46`,
  `Task/Views/RootView.swift:91-94`,
  `Task/Views/Task/TaskDetailView.swift:481,487-491`
- **Description:** `requestAuthorizationIfNeeded()` only prompts when
  `authorizationStatus == .notDetermined`. If the user denies the
  prompt (or later turns notifications off in iOS Settings), subsequent
  calls to `schedule(for:)` happily build a `UNNotificationRequest` and
  hand it to `UNUserNotificationCenter.add(...)` — which iOS silently
  drops. The app shows the alarm icon on the card and the task is
  saved with `hasReminder = true`, but no notification will fire. The
  user has no signal.
- **Why it matters:** A reminder the user believes is set is the worst
  silent failure for a task app. Easy to reproduce on a fresh device
  where the user dismisses the system permission alert.
- **Suggested fix:** Cache the current `authorizationStatus` (in
  `SharedDefaultsService` or in `SettingsViewModel`) and surface a
  one-shot banner inside `TaskDetailView` when the user toggles
  reminder on while authorization is `.denied`. Optionally a
  Settings → Notifications row that deep-links to
  `UIApplication.openSettingsURLString`.
- **Risks / dependencies:** Async authorization checks need to fall
  back gracefully if the system call fails. The schedule call should
  remain non-blocking; the banner is the only synchronous UI change.

### N12. `TaskDetailView.save` silently strips a reminder if the user removes all dates

- **Severity:** Medium
- **Related files:** `Task/Views/Task/TaskDetailView.swift:281-287,481`
- **Description:** The reminder Toggle is `.disabled(workingStart == nil
  && dueDate == nil)` so the user can't *enable* a reminder with no
  dates. But the converse is unprotected: the user can turn reminder
  on (with dates set), then clear all dates, then save. Line 481
  resolves `task.hasReminder = hasReminder && (workingStart != nil ||
  dueDate != nil)` — silently flipping the local `hasReminder` state
  to `false` on disk while the user's last interaction was leaving it
  on. No banner, no warning.
- **Why it matters:** Same silent-failure class as N11. The user
  meant to keep the reminder; removing the dates implicitly drops it.
- **Suggested fix:** Mirror the disable rule in the editor: when the
  user clears the last date with `hasReminder = true`, surface a
  toast ("Reminder removed — no date set") or zero out
  `hasReminder` immediately in the state so the Toggle visibly turns
  off. The latter matches the disabled Toggle pattern and avoids the
  surprise.
- **Risks / dependencies:** None.

### N13. `Board.defaultGroupID` is typed `String?` instead of `UUID?`

- **Severity:** Low
- **Related files:** `Task/Models/Board.swift:14,46-53`,
  `Task/Views/Settings/DefaultStatusPickerSheet.swift:22`,
  `Task/Services/DataImportExport.swift:24,206,280,291`
- **Description:** Every other entity ID on the model is `UUID`
  (Board.id, Group.id, Task.id, Tag.id, task.tagIDs in TaskExport).
  `defaultGroupID` is stored as a `String?` and compared via
  `$0.id.uuidString == id`. This works but is inconsistent and means
  the model accepts arbitrary strings that aren't valid UUIDs
  (silently failing the lookup and falling back to
  `orderedGroups.first`). A malformed JSON import that hand-edited
  this field would not be detected.
- **Why it matters:** Type consistency. Will become a question again
  if the schema is migrated to add other "optional ID" fields.
- **Suggested fix:** Change to `var defaultGroupID: UUID? = nil`,
  rename the accessor to compare on `UUID` directly, and migrate
  `BoardExport.defaultGroupID` from `String?` to `UUID?` (existing
  exports decode fine because both serialize the same string form).
- **Risks / dependencies:** SwiftData property-type changes require a
  lightweight migration. Since the field already has a default
  (`nil`), the migration is automatic but should be verified once.

### N14. `RepeatRule` feature is half-implemented — repeats do not re-schedule

- **Severity:** Low
- **Related files:** `Task/Models/RepeatRule.swift:21-30`,
  `Task/Models/TaskItem.swift:15,57-60`,
  `Task/Views/Task/TaskDetailView.swift:289-319,497-504`,
  `Task/Views/Task/RepeatPickerSheet.swift:1-62`,
  `Task/Views/Board/TaskCardView.swift:38-45`,
  `Task/Services/NotificationService.swift:43`
- **Description:** A user can set a task to repeat Daily / Weekly /
  Monthly, which adds an `arrow.clockwise` icon on the card footer
  and shows the repeat row in the editor. But:
  - `NotificationService.schedule` builds
    `UNCalendarNotificationTrigger(dateMatching:repeats: false)` —
    repeats are always `false`, so the reminder fires once.
  - There is no concept of "completing" a task that would advance
    the repeat to the next occurrence.
  - The only way to advance dates is the manual "→" button on the
    repeat row, which the user must remember to tap.
  Effectively the repeat is a card-decoration plus a manual date
  shifter, not a recurring reminder.
- **Why it matters:** Users see "Daily" and expect daily reminders.
  When the second day passes without a notification, they conclude
  the reminder didn't work.
- **Suggested fix:** Two options:
  - (a) Pass `repeats: true` to `UNCalendarNotificationTrigger` when
    `repeatRule != .none`, with the components reduced appropriately
    (e.g. `.daily` → keep `hour`/`minute`; `.weekly` → keep `weekday`/
    `hour`/`minute`). Match the documented behavior.
  - (b) Document the manual-advance behavior in HowToUseSheet, or
    rename the icon "Manual Repeat" to reset expectations.
  - (c) Skip the feature entirely until there's a "Done" concept that
    would naturally trigger a repeat re-schedule.
- **Risks / dependencies:** Option (a) needs care: `UNCalendarNotification
  Trigger` repeating on day-only components fires at midnight unless
  hour/minute are set. Pull the per-board reminder time logic out of
  the current `schedule` and feed it back through.

### N15. `DateFormatters.mediumWithTime` and `isSameDay` are unused

- **Severity:** Low
- **Related files:** `Task/Utils/DateFormatters.swift:11-16,29-31`
- **Description:** `grep -rn 'mediumWithTime\|isSameDay' --include='*.swift'`
  returns only the definitions. Both are dead.
- **Why it matters:** Slow accretion of dead code.
- **Suggested fix:** Remove them. If a future feature needs
  `mediumWithTime`, add it back at that point.
- **Risks / dependencies:** None.

### N16. README "folder button" vs implementation's `archivebox` icon

- **Severity:** Low
- **Related files:** `README.md:26`, `VersionHistory.md:11,42`,
  `Task/Components/BottomNavBar.swift:48,89`
- **Description:** README and VersionHistory both describe the
  board-switcher control as a "folder button (`folder.fill`)", but
  `BottomNavBar` uses `systemName: "archivebox"` on both the
  liquid-glass and legacy variants. The HowToUseSheet line 101 uses
  `"archivebox.fill"` which at least matches the in-app icon shape.
- **Why it matters:** Docs vs. code drift. Minor on its own; can
  confuse new contributors trying to find the button by SF Symbol
  name.
- **Suggested fix:** Either change the symbol to `"folder.fill"` in
  `BottomNavBar` so it matches the docs, or update README and
  VersionHistory to say "archivebox" (or "archive box"). The
  archivebox icon may actually be the better visual for "board
  switcher".
- **Risks / dependencies:** None.

### N17. `Board` model has unused default `"TooMuchToDo"` / `"Work Harder Play Harder"`

- **Severity:** Low
- **Related files:** `Task/Models/Board.swift:7-8,28-31`,
  `Task/Services/SwiftDataManager.swift:40-44,60-70`,
  `Task/Views/Board/BoardSwitcherView.swift:183-191`
- **Description:** `Board.title` defaults to `"TooMuchToDo"` and
  `Board.subtitle` defaults to `"Work Harder Play Harder"`. Neither
  string is ever actually persisted in user data, because every
  Board-creating code path supplies values:
  - `defaultSeedBoards` uses "Personal" / "Study" / "Work".
  - `BoardSwitcherView.addBoard` uses "Choose a Title" / "Choose a
    Subtitle".
  - `DataImportExport.mergeBoard` uses the imported `BoardExport`
    values.
  The defaults are placeholders left over from early development
  that never reach the user — but they'd surface if someone called
  `Board()` with no arguments.
- **Why it matters:** Quiet trap: a future `Board()` call would
  inherit these strings. Also reads like a personal note.
- **Suggested fix:** Change defaults to neutral, localizable strings
  (`String(localized: "New Board")` / `""`) or to required init
  parameters with no defaults.
- **Risks / dependencies:** SwiftData requires every `@Model`
  property to have a default — so the simplest move is to set them
  to empty strings (`""`) and let callers always supply values.

### N18. Import success pluralization is built by string concatenation, not localized plural rules

- **Severity:** Low
- **Related files:** `Task/Views/Settings/SettingsView.swift:425-432`
- **Description:** `orphanMessage(for:)` constructs:
  ```swift
  String(localized: "\(outcome.orphanTasks) task(s) moved to the first group …")
  ```
  The literal "(s)" is a hack — `Localizable.xcstrings` supports
  `.stringsdict`-style pluralization (`zero`, `one`, `other`) for
  English and Chinese, but this string forces one form for all
  counts. With a count of 1 the message reads "1 task(s) moved",
  which is jarring.
- **Why it matters:** Visible only when import surfaces orphan
  counts, but every appearance is awkward.
- **Suggested fix:** Convert to a String Catalog plural variation
  (the `.xcstrings` UI in Xcode supports this directly), with at
  least `one` and `other` for both en and zh-Hans.
- **Risks / dependencies:** Adds two new entries to the catalog;
  remove the old `(s)` ones.

### N19. The image-import path doesn't show how many entities were updated vs inserted

- **Severity:** Low
- **Related files:** `Task/Services/DataImportExport.swift:147-153,245-267,425-432`,
  `Task/Views/Settings/SettingsView.swift:103-131`
- **Description:** `ImportResult` carries `orphanTasks` and
  `orphanTagRefs` but not the number of new boards inserted, the
  number of existing boards updated, or the count of merged
  groups/tags. The user sees "Import Successful" plus the orphan
  string (when nonzero), but no positive number — they can't tell
  whether the import actually did anything when both orphan counts
  are zero. This particularly matters when reimporting an unchanged
  backup: the result looks identical to importing an empty file.
- **Why it matters:** Trust signal. Users want to know "the file
  was understood and N tasks were touched".
- **Suggested fix:** Extend `ImportResult` with `boardCount`,
  `taskCount`, and (optionally) `inserted`/`updated` counts; render
  them in the alert message ("Imported 3 boards, 412 tasks (12 new,
  400 updated).").
- **Risks / dependencies:** Touches the public shape of the result
  struct and the alert copy (which would then need translation
  again).

---

## 3. Code quality findings

- **Duplicated code:**
  - Drag-to-delete trash zone is implemented three times nearly
    identically in `BoardSwitcherView.swift:148-181`,
    `TagPickerSheet.swift:151-184`, and
    `StatusPickerSheet.swift:149-181`. Same RoundedRectangle, same
    `hovered ? .85 : .45` opacity, same hide-debounce in
    `onChange(of: dragOverScreen)`. A shared `DeleteDropZone(hovered:
    onDrop:)` view would collapse three copies of ~30 lines each.
  - Drag-and-drop state machine (`@State draggingID`, `dragSessionEnded`,
    `dragOverScreen`, `showDeleteZone`, `hideDeleteZoneTask`) is
    reproduced in the three pickers above plus `ManageGroupsView` and
    `ManageTagsView`. The orphans (N3) duplicate the live ones.
  - Snapshot/save bookkeeping (`try? context.save()` + `UpcomingSnapshot
    Builder.writeSnapshot(from: context)`) appears in 9 sites
    (BoardView.swift:88-89, GroupMenuSheet.swift:98-99,115,
    ProjectHeaderView.swift:74-75,124,
    StatusPickerSheet.swift:262-263, TaskDetailView.swift:485,510-511,
    DataImportExport.swift:264-265,444-447, SwiftDataManager.swift:87-88).
    A `Repository.save(context:)` helper would centralize the
    invariants.
  - `BoardReorderDropDelegate`, `StatusPickerReorderDropDelegate`,
    `TagPickerReorderDropDelegate`, `GroupReorderDropDelegate`, and
    `TagReorderDropDelegate` all share the same shape (`applyMove`
    + sortIndex renumber + save) over different model types. A
    generic `ReorderDropDelegate<Item>` would unify them.

- **Unused or outdated files / symbols:**
  - `Task/Views/Settings/DefaultStatusPickerSheet.swift` —
    instantiated nowhere (N1).
  - `Task/Views/Settings/ManageGroupsView.swift` — instantiated
    nowhere (N3).
  - `Task/Views/Settings/ManageTagsView.swift` (including
    `TagEditSheet`) — instantiated nowhere (N3).
  - `Task/Utils/DateFormatters.swift:11-16` — `mediumWithTime`
    unused (N15).
  - `Task/Utils/DateFormatters.swift:29-31` — `isSameDay` unused
    (N15).
  - `Task/Models/Board.swift:7-8` — defaults `"TooMuchToDo"` /
    `"Work Harder Play Harder"` never reach the user (N17).

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` (515 lines) — title +
    six property rows + two date sub-sheets + repeat picker + delete
    confirmation + save/load/delete. Splitting `workingDateSheet`,
    `dueDateSheet`, and `propertyRow` into their own files would
    halve this.
  - `Task/Views/Settings/AboutSheets.swift` (478 lines) — eight
    sheet types plus shared cards. Each `*Sheet` could move to its
    own file.
  - `Task/Services/DataImportExport.swift:269-430` —
    `mergeBoard(_:into:)` is ~160 lines covering board / groups /
    tags / tasks merge. Extracting `mergeGroups`, `mergeTags`,
    `mergeTasks` would keep N1's fix small.
  - `Task/Views/Board/BoardSwitcherView.swift` (298 lines) — the
    drag-to-delete drop zone (N3 duplication) and the two
    DropDelegate helpers could be lifted.

- **Naming inconsistencies:**
  - `BoardSwitcherView` uses `"Close"` for the dismiss button;
    every other sheet uses `"Cancel"` or `"Done"` (N9).
  - `ColumnView`'s drag payload prefix `"group:"` (line 21,
    `groupDragPrefix`) is also referenced as a literal string in
    `ColumnView.swift:222-223`. The constant and the literal can
    diverge.
  - `Board.cardSortFieldRaw` is `String` while
    `Board.defaultGroupID` is `String?` — both are "stringly-typed
    SwiftData fields", same backing pattern, but neither is
    documented as such (N13).

- **Structural improvements:**
  - Funnel every snapshot write + widget reload through a single
    `BoardWriter` actor. Today every save site has to remember to
    call `UpcomingSnapshotBuilder.writeSnapshot`. A
    `BoardWriter.save(board:context:)` that bundles all three
    (`board.updatedAt = Date(); context.save(); writeSnapshot`) would
    make it harder to drop the snapshot update again (as happened
    pre-0.4.5 with N3 in the archive).
  - Move per-target color palette duplication
    (`ColorKey` ↔ `WidgetColorKey`) behind a tiny shared package or
    file the build copies into both targets; the two enums must agree
    by hand today.

---

## 4. Functional issues

- **Boards** — Default seed (Personal / Study / Work) is verified by
  `testSeedCreatesThreeDefaultBoards`. Switcher reorder, add, and
  drag-to-delete all behave as documented. Active-board fallback on
  delete works because the `boards` snapshot is captured before the
  delete commits.
- **Board / columns / cards** — Pagination, `.id()` re-render on sort
  change, and pull-to-refresh all work. Card drag-reorder correctly
  no-ops in non-Manual sort modes (per the archive's N2 resolution).
- **Drag and drop** — Cross-column drops save once (placed via
  `placeTask` with `commit: true`); within-column live drag yields
  smoothly. Trash zone behaviour is identical across the three
  pickers but the implementations are duplicated (see §3).
- **Calendar picker** — Today button (added in 0.3.0) jumps + selects
  correctly. Range mode after both endpoints are set resets to a new
  single-day selection on any non-endpoint tap; the docs (LessonsLearned)
  mention this; users may still find it surprising.
- **Search** — Cross-board search works and the active board surfaces
  first. `filteredTasks` recomputes every body update — fine at
  current expected scale, but a noticeable perf cost as boards grow.
- **Default Status picker** — **regressed** (N1); user cannot change
  which group new tasks default to.
- **Manage Groups / Manage Tags screens** — orphaned (N3); group/tag
  editing is done in-flow through the column `…` menu, in-task
  pickers, and the trash drop zones.
- **Import / Export / Reset** — Round-trips correctly for self-exported
  data. Orphan counts are surfaced in the success alert; the surface
  copy is a partial fix (N18, N19). Reset feels like a hang on large
  data (N7).
- **Notifications** — Past-date guard is in place. Authorization-
  denied is not surfaced (N11). Reminder silently dropped when dates
  are cleared after toggling reminder on (N12). RepeatRule is
  half-wired (N14).
- **Widget snapshot** — `UpcomingSnapshotBuilder.writeSnapshot` now
  calls `WidgetCenter.shared.reloadAllTimelines()` from every save
  site. Snapshot date encoding is `.iso8601` on both sides
  (matches widget decoder). Board list is rewritten on every
  snapshot write so the configuration intent's `BoardEntityQuery`
  always sees current boards.
- **Localization** — Catalog covers many strings but 58% of zh-Hans
  entries are missing (N10). Dates render in device locale rather
  than `settings.language.locale` (N6).

---

## 5. UI/UX issues

- **N1 (Default Status unreachable)** — feature regression visible to
  every multi-board user creating a new task.
- **N2 (HowToUseSheet stale paths)** — user-visible misdirection.
- **N4 (Reset copy says "six groups")** — pre-confirmation copy
  drift; mildly misleading for a destructive action.
- **N5 (BoardIconPickerSheet Cancel does nothing)** — undermines
  Cancel semantics.
- **N7 (Reset shows no progress)** — apparent hang.
- **N8 (iCloud Sync looks tappable)** — discoverability hiccup, same
  shape as the archive's N10.
- **N9 (sheet toolbar inconsistency)** — polish.
- **N12 (silent reminder drop on date clear)** — surprise.
- **N16 (folder vs archivebox)** — docs vs code drift.
- **Drag preview shapes** — all use `.contentShape(.dragPreview,
  RoundedRectangle(cornerRadius: 22, …))` for grids and
  `cornerRadius: 10` for cards. No green `+` badge anywhere. Matches
  LessonsLearned guidance.
- **"More +N" button** — `+N = min(pageSize, hidden)`, so a 47-task
  column shows "More +10" three times then "More +7". Reads fine,
  but the chip means "next chunk size", not "remaining total" — a
  one-line clarification ("More +10 (37 left)") would set the
  expectation right.
- **iOS 26 fallback parity** — `BottomNavBar` forks via
  `#available(iOS 26.0, *)`; the iOS 18-25 fallback uses
  `.thinMaterial` + `secondarySystemBackground` circles with the same
  control set. No regressions vs the Glass variant. Verified via
  code read; not verified on-device.
- **MarkdownNotesEditor** — Markdown preview is clean; tapping any
  rendered line jumps back into edit mode. The blank-line handler
  (line 75-79) renders a clear 8 pt area whose `onTapGesture`
  triggers `beginEditing()` — works but is a narrow hit target.

---

## 6. Data and persistence issues

- **N13 (defaultGroupID typed as String)** — invariant drift risk.
- **N17 (Board default placeholders)** — silent trap if a future
  call site calls `Board()` without arguments.
- **In-memory fallback signal** — RootView surfaces the alert
  exactly once per launch via
  `surfaceInMemoryWarningIfNeeded`. The `inMemoryFallbackKey` is
  flipped to `false` on the next successful container open. Good.
- **Cascade deletes** — `Board.groups`/`tags`/`tasks` all set
  `deleteRule: .cascade`. `BoardGroup.tasks` uses `.nullify` — so
  deleting a group through SwiftData alone would orphan its tasks.
  Live delete paths (GroupMenuSheet.deleteAndDismiss,
  StatusPickerSheet.deleteGroup) reassign tasks to the fallback
  group before deleting; the cascade-from-Board path (in
  `resetAll`) deletes everything anyway, so no orphan.
- **CloudKit-readiness invariants hold**: every `@Model` property in
  `Board.swift`, `BoardGroup.swift`, `TaskTag.swift`,
  `TaskItem.swift` has a default value, no `@Attribute(.unique)`,
  optional inverse relationships.
- **Snapshot encoding** — both write paths use `.iso8601`; widget
  decoder matches. Archive's N15 resolved.
- **Board list write** — `UpcomingSnapshotBuilder.writeSnapshot`
  writes both the snapshot and the board list via
  `SharedDefaultsService.writeBoardList(...)` on every save site.
  The widget's `BoardEntityQuery` therefore reflects current
  boards.
- **`writeBoardList` uses default `JSONEncoder()`** —
  `SharedDefaultsService.swift:53-58` doesn't set
  `dateEncodingStrategy`, but `BoardListEntry` has no `Date` fields,
  so it's a non-issue today. If a `Date` is ever added,
  remember to mirror the `.iso8601` rule.
- **Export ordering** — `BoardExportEntry.tasks` are written in
  whatever order `(board.tasks ?? [])` returns; round-trip still
  works since `sortIndex` is persisted, but the exports are not
  byte-identical across runs. Carry-over from prior audit.
- **`task.boardDefaultsMigrated` after reset** — `resetAll` does not
  clear this flag. Correct today (migration is one-shot), but if a
  future build wants a second one-shot migration with the same key,
  resets prior to that build would silently skip it. Easy to avoid
  by namespacing future migration keys by version.

---

## 7. Configuration and platform issues

- **DEVELOPMENT_TEAM is still hardcoded** to `U6KN3BQL72` in
  `task.xcodeproj/project.pbxproj` (lines 451, 488, etc.). Same as
  prior audit; blocks contributors from a clean Archive without
  edits. Move to `.xcconfig` for collaboration-readiness.
- **iOS deployment target 18.0** in all four targets — matches
  README requirements.
- **App Group `group.com.ijustin.task`** is correctly configured on
  both `Task.entitlements` and `TaskWidgetExtension.entitlements`.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  remains excluded via `PBXFileSystemSynchronizedBuildFileExceptionSet`
  (lines 56-62 in pbxproj). Same as prior audit. Task target uses
  `GENERATE_INFOPLIST_FILE = YES` with the
  `INFOPLIST_KEY_*` settings — no checked-in Task/Info.plist needed.
- **`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet
  Midnight Neutral Light"`** (line 444) matches `AppIconOption.alternateName`
  (Classic / Rose / Violet / Midnight / Neutral / Light, where
  Classic is the primary). Not verified against the asset catalog
  contents.
- **PrivacyInfo.xcprivacy** declares `NSPrivacyAccessedAPICategoryUserDefaults`
  with reason `CA92.1` (App Group sharing). Correct.
- **Portrait-only orientation** in
  `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`
  for both Task release & debug configurations. Matches the
  UI which has not been laid out for landscape.
- **`LSApplicationCategoryType = public.app-category.productivity`**
  set — App Store category-ready.
- **`TARGETED_DEVICE_FAMILY = 1`** (iPhone only). Matches design.
- **`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`** — set on both
  targets; new strings auto-extract on build.

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - Default Status picker entry point + persistence (the regressed
    feature in N1, once restored).
  - Multi-board import / export round-trip integrity at v2 wire
    format, plus the legacy v1 fall-back path
    (`DataImportExport.decodePayload`).
  - Cross-board task isolation: a task added to board A must not
    appear in board B's search results (`SearchView.groupedResults`)
    or column rendering.
  - Drag-reorder math in all five drop delegates
    (`BoardReorderDropDelegate`, `StatusPickerReorderDropDelegate`,
    `TagPickerReorderDropDelegate`, `GroupReorderDropDelegate`,
    `TagReorderDropDelegate`).
  - Group delete reassignment (`GroupMenuSheet.deleteAndDismiss`,
    `StatusPickerSheet.deleteGroup`).
  - `migrateLegacyBoardDefaultsIfNeeded` one-shot path: prove a
    legacy install with `task.cardSortField = "workingDate"` ends
    up with `cardSortFieldRaw = "date"` on the first board.
  - `primaryReminderDate` returns `min(workingStart, dueDate)` and
    `NotificationService.schedule` past-date skip.
  - Snapshot encoding round-trip between
    `SharedDefaultsService.UpcomingSnapshot` and
    `WidgetUpcomingSnapshot`, both directions.
- **Suggested tests:**
  - `testDefaultStatusFallsBackToFirstGroupWhenIDInvalid()` — set
    `board.defaultGroupID = "not-a-uuid"`, assert `board.defaultGroup
    == board.orderedGroups.first`.
  - `testImportThenExportThenImportProducesEqualBoards()` — import
    a payload, export, re-import, compare board / group / tag /
    task counts and IDs.
  - `testImportV1LegacyPayloadDecodes()` — feed
    `LegacySingleBoardPayload`-shaped JSON, assert it lands as a
    single-entry MultiBoard payload.
  - `testImportOrphanTaskLandsInFallbackGroup()` — import a task
    whose `groupID` is absent from the file, assert it ends up in
    `board.orderedGroups.first` and `outcome.orphanTasks == 1`.
  - `testGroupDeleteReassignsTasks()` — set up 5 tasks in group A,
    delete A via `deleteAndDismiss`, assert all 5 tasks now belong
    to the remaining first group.
  - `testReorderWithinColumnRenumbers()` — set 5 tasks with
    sortIndex 0..4, call `BoardView.placeTask(task: tasks[4],
    in: group, atIndex: 0)`, assert new sortIndex order.
  - `testReorderNoOpInNonManualSort()` — in title sort, drag the
    third title to position 0; assert sortIndex was unchanged.
  - `testNotificationPastDateSkips()` — set a past due date, call
    `NotificationService.schedule`, assert
    `UNUserNotificationCenter.current().getPendingNotificationRequests`
    has no entry for this task id. Requires test-host entitlements.
  - `testSnapshotEncodingMatchesWidgetDecoder()` — encode an
    `UpcomingSnapshotEntry`, decode as `WidgetUpcomingEntry`,
    assert field-by-field equality including the new `boardID` /
    `boardEmoji` / `boardTitle`.
  - `testMigrateLegacyBoardDefaults()` — preload UserDefaults
    legacy keys, run `ensureSeed`, assert the first board picks up
    the migrated values and `task.boardDefaultsMigrated` is set.
- **Manual / device-only:**
  - Verify widget refreshes promptly after task edits in a real
    widget install across all three families.
  - Verify the alternate-icon picker actually swaps icons on iOS 18
    and iOS 26 (requires runtime `setAlternateIconName`).
  - VoiceOver pass over `BottomNavBar`, `BoardSwitcherView` (drag-to-
    delete), `BoardView`, `TaskDetailView`.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — Restore the Default Status entry point (add the icon
    button in `ProjectHeaderView`). One-screen change with high
    user impact.
  - **N2** — Rewrite the three stale `HowToUseSheet` steps so docs
    match the live UI. Trivial but visible; pairs with N1's fix.
  - **N4** — Fix the Reset confirmation copy. Three-word change in
    one file; reduces user confusion before a destructive action.
  - **N3** — Decide to delete or revive the orphan files; remove
    the dead code if no Settings re-entry is planned.
- **Fix next:**
  - **N5** — Either remove `BoardIconPickerSheet`'s Cancel button
    or make it actually cancel.
  - **N7** — Show a `ProgressOverlay` during Reset.
  - **N6** — Have `TaskDateFormat` honor the user-selected locale.
  - **N8** — Convert the iCloud Sync row to a proper "coming soon"
    button or dim its title.
  - **N9** — Codify the sheet toolbar rule and apply across the
    app.
  - **N11** — Surface a banner when the user enables a reminder
    with notification authorization denied.
  - **N12** — Don't silently strip a reminder when the user
    removes the last date; either zero the toggle visibly or
    show a hint.
  - **N10** — A focused zh-Hans translation pass before the next
    Chinese-targeted release.
- **Optional cleanup:**
  - **N13** — Migrate `Board.defaultGroupID` from `String?` to
    `UUID?`.
  - **N14** — Either wire `repeats: true` through
    `UNCalendarNotificationTrigger` or document the manual-advance
    pattern.
  - **N15** — Remove `mediumWithTime` and `isSameDay`.
  - **N16** — Reconcile README's "folder button" with the
    archivebox SF Symbol.
  - **N17** — Replace `Board`'s placeholder defaults with empty
    strings or required parameters.
  - **N18** — Convert the import success pluralization to proper
    String Catalog plural variations.
  - **N19** — Extend `ImportResult` with positive counts so the
    success alert reports what was actually imported.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- `docs/IssuesArchive-01.md` cross-referenced against current code
  for every prior issue (N1-N15 in that archive).
- All Swift sources under `Task/`:
  - Models (`Board`, `BoardGroup`, `TaskTag`, `TaskItem`,
    `ColorKey`, `RepeatRule`).
  - Services (`SwiftDataManager`, `NotificationService`,
    `SharedDefaultsService`, `UpcomingSnapshotBuilder`,
    `DataImportExport`).
  - Utils (`AppInfo`, `DateFormatters`).
  - ViewModels (`SettingsViewModel`).
  - Views (`RootView`, board / board switcher / task detail /
    search / settings, including each picker sheet).
  - Components (`BottomNavBar`, `CalendarPicker`, `CardBackground`,
    `ColorSwatchPicker`, `ConfirmationSheet`, `DateRow`,
    `FlowLayout`, `GridTile`, `GroupHeaderPill`, `ProgressOverlay`,
    `SettingsCard`, `StringMoveDropDelegate`, `TagChip`).
- All Swift sources under `TaskWidgetExtension/`
  (`TaskWidgetBundle`, `UpcomingTasksProvider`,
  `UpcomingTasksWidget`, `WidgetSnapshot`, `BoardConfigurationIntent`).
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`, `TaskWidgetExtension/Info.plist`.
- `task.xcodeproj/project.pbxproj` — build settings, synchronized
  folder exceptions, code signing, marketing/current version,
  INFOPLIST keys, bundle IDs, asset catalog config.
- `Task/Localizable.xcstrings` — programmatic count of total keys
  vs zh-Hans `state: "translated"`, plus spot checks for unlocalized
  literals via `grep -rn 'Text(\"'`.
- `TaskTests/TaskTests.swift`.
- Grep queries:
  - `DefaultStatusPickerSheet`, `ManageGroupsView`, `ManageTagsView`
    (to confirm orphans).
  - `RepeatRule\|repeatRule\|repeatRuleRaw` (to map the half-wired
    repeat feature).
  - `WidgetCenter`, `reloadAllTimelines` (archive N1 verification).
  - `\.swipeActions` (archive N6 verification — no live matches).
  - `task.*Key` UserDefaults keys (consistency between
    `SharedDefaultsService`, `SwiftDataManager`, and
    `WidgetSharedDefaults`).
  - `mediumWithTime|isSameDay` (dead code).
  - `folder.fill\|archivebox` (doc vs code drift).

## Not checked (worth a follow-up)

- Actual runtime behavior on iOS 18.x vs iOS 26 devices /
  simulators (Liquid Glass parity, alternate icon transitions,
  drag previews, ProgressOverlay animation while @MainActor work
  runs, widget reload cadence).
- On-device notification delivery, authorization-denied paths,
  notification body composition in different locales.
- Instruments / memory profile (board with thousands of tasks;
  SearchView at scale).
- Widget rendering under each `WidgetFamily` on a real device, and
  the configuration intent picker after a board rename.
- Asset catalog contents
  (`Rose/Violet/Midnight/Neutral/Light` and the corresponding
  `*Preview` previews actually exist;
  `INCLUDE_ALL_APPICON_ASSETS = YES` is set but the catalog itself
  is not part of this audit).
- Full pass of `Localizable.xcstrings` for missing `zh-Hans`
  translations against every emitted key (counted, not enumerated).
- Accessibility audit (Dynamic Type, VoiceOver labels, hit
  targets, drag-and-drop accessibility).
- Verifying that `task.boardDefaultsMigrated` actually fires for a
  legacy upgrade user (would require launching the app with the
  legacy UserDefaults pre-populated).
