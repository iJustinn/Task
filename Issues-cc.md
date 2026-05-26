# Task — Issues Report

Audit of branch `task-v0.4.7` on 2026-05-26. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.4.7 (build 6 per `README.md` and `VersionHistory.md`; build 7 per
`task.xcodeproj/project.pbxproj` — see N3) is in very good shape. Every
issue from `docs/Issues-cc-04.md` is resolved:
`ConfirmationSheet` accepts `LocalizedStringKey` for `title`, `message`,
`confirmLabel`, and `cancelLabel`; `SettingsButtonRow.title`,
`SettingsRowLabel.title`, and `SheetActionButtonLabel.title` likewise
accept `LocalizedStringKey`; `StatusPickerSheet.sheetTitle` and
`TagPickerSheet.sheetTitle` return `LocalizedStringKey`; the widget target
ships its own `TaskWidgetExtension/Localizable.xcstrings` with all 17
required keys translated; `UpcomingSnapshotBuilder.writeSnapshot` filters
out `showsCheckbox && isChecked` tasks so the widget reflects the checkbox
state; `UpcomingTasksProvider.filter` drops a cross-board status filter
instead of locking the widget into "No upcoming"; the `→` advance
button's accessibility label now reads "Advance to next occurrence"; the
repeat picker uses `^[\(count) task](inflect: true)` for plural
inflection; the string catalog now reports 248 active keys with 0 stale
entries (down from 273/77 stale) and 100% zh-Hans coverage; the
`notesPreviewKey` is now `task.notesPreview` with a dual-read fallback to
the legacy `task.notesPreviewEnabled`. New v0.4.7 build 6 work
(`SwipeToEditRow` swipe-to-edit on status/tag rows, status/tag picker
redesign, board date slider, Markdown editor, widget board+status filter,
per-task checkbox, biweekly/quarterly/annually repeat options, Storage
Check row, board-specific Cards per Column limit on each status, the
CalendarPicker "Clear" button alongside "Today", duplicate-task action)
is functionally sound. **Remaining issues cluster around two themes.**
First, a single architectural change in `NotificationService` collapses
the repeating-reminder schedule to a one-shot
(`schedule(for:)` → `[resolvedAnchor]`) so "Daily" / "Weekly" / etc. now
fire **once** on the next occurrence and stop — the user must open the
editor and tap `→` to advance for the next ring. This is intentional per
the `testRepeatingReminderDoesNotAdvancePastCardDate` test but is
undocumented in VersionHistory and not surfaced in the UI, so users who
previously relied on repeating reminders will perceive it as broken.
Second, `AboutSheets` declares `AboutInfoSection.title: String`,
`AboutInfoSection.details: [String]`, `AboutGuideSection.title: String`,
and `AboutGuideSection.steps: [String]` — the same `String`-instead-of-
`LocalizedStringKey` shape that N1 / N2 / N3 fixed for ConfirmationSheet
and Settings rows. As a result, eleven section titles ("Create Tasks",
"Notes & Checklists", "Organize the Board", "Tags & Groups", "Dates &
Reminders", "Defaults", "Widget", "Local-First Data", "Network Access",
"Notifications", "Your Control") and every detail/step paragraph on the
How to Use, Privacy, and Disclaimer sheets are MISSING from the catalog
entirely; Chinese users see those surfaces in English. Areas reviewed:
models, services (including the simplified `NotificationService`,
`UpcomingSnapshotBuilder`, `SharedDefaultsService`, `DataImportExport`
with the new `DataStorageSummary`), view models (`SettingsViewModel`
with the new dual-key `notesPreview` read), all views (board with the
date slider, board switcher, task detail with the duplicate flow and
inline reminder warnings, status/tag picker sheets with swipe-to-edit
and the consolidated `ReorderDropDelegate`, search, settings including
Storage Check and Notes Preview enum, customization including the
redesigned repeat picker, About sheets, components including
`SwipeToEditRow`, `ConfirmationSheet`, `CalendarPicker` with the new
Clear button, the Markdown notes editor with its UIKit
`LiveMarkdownTextView`), widget target (snapshot shape with the new
optional fields, configuration intent including the cross-board
guard, filter logic, target-isolated catalog), project configuration
including `Config/Signing.xcconfig`, entitlements, privacy info,
`task.xcodeproj/project.pbxproj`, `Localizable.xcstrings` and
`TaskWidgetExtension/Localizable.xcstrings` coverage (248 + 17 keys,
both 100% zh-Hans translated). Not reviewed: live runtime behavior on
device, on-device notification delivery, widget rendering on a real
Home Screen, Instruments traces, asset catalog contents, TestData JSON
integrity.

---

## 2. Issue list

### N1. Repeating reminders only fire once; "Daily" no longer means daily

- **Severity:** High
- **Related files:** `Task/Services/NotificationService.swift:21-64`,
  `Task/Views/RootView.swift:64-72`,
  `Task/Views/Task/TaskDetailView.swift:377-394,651-655`,
  `Task/Views/Board/TaskCardView.swift:48-66`,
  `TaskTests/TaskTests.swift:61-91`
- **Description:** `NotificationService.fireDates(for:)` returns a single
  date for every task with `hasReminder == true`:
  ```swift
  // Repeat controls date advancement on the task card, not notification recurrence.
  return [resolvedAnchor]
  ```
  `schedule(for:)` then registers exactly one `UNCalendarNotificationTrigger`
  on the task's `primaryReminderDate`. When that date passes, no further
  notification is scheduled until either (a) the user opens the editor
  and taps the `→` chip on the Repeat row to call `advanceRepeatDates()`
  on the working / due dates, or (b) the user manually edits the dates.
  `RootView.refreshRepeatReminders` on scene-active re-invokes
  `schedule(for:)`, but with the new logic that just re-arms the single
  one-shot — no automatic advance happens anywhere. The two
  `testRepeatingReminder*` cases confirm this is intentional: a daily
  rule with a past date produces an empty fire-date list. Surfaces with
  no warning to the user that "Daily" / "Weekly" / etc. don't auto-recur:
  - The Repeat row in `TaskDetailView` still shows the rule's name
    (`Daily`, `Weekly`, …) as if it were a recurrence schedule.
  - The card footer's `arrow.clockwise` icon
    (`TaskCardView.swift:52-55`, new in build 6) indicates the task
    repeats, with no hint that the next ring requires manual advance.
  - The reminder anchor's `alarm` icon stays on the same row after the
    one-shot fires, suggesting "still scheduled" when nothing more is.
  - The Dates & Reminders How to Use card promises
    "Reminders fire at the time you set per-board" — no mention of
    needing to manually advance for repeats.
- **Why it matters:** Most users who set "Daily" expect a daily ring.
  After the first occurrence elapses, the task silently stops reminding
  and the user has no way to know without re-opening the editor and
  noticing the date hasn't moved. The strongest case is the medication-
  reminder / drink-water-daily archetype — exactly the audience the
  Repeat feature was added for.
- **Suggested fix:** Pick one of:
  - (a) **Auto-advance on scene-active / app launch.** In
    `RootView.refreshRepeatReminders`, when a repeating task's
    `primaryReminderDate` is in the past, advance every date by one
    rule occurrence until it's in the future before re-scheduling.
    Persist the change. Pairs with how `RootView` already runs this on
    `scenePhase == .active`. This preserves the user expectation that
    "Daily" means daily.
  - (b) **Schedule a finite future batch like before.** Revive the
    16-occurrence batch in `fireDates(for:)` for tasks with a non-`.none`
    `repeatRule`, keyed by `task.id.uuidString` + `@<index>` (matching
    the legacy identifier shape that `cancel(for:)` already cleans up).
    Closest to the prior behavior; downside is the user's manually
    advanced date can drift from the batch.
  - (c) **Surface the new contract.** Rename `repeatRule` UI to
    "Auto-advance dates" or add an inline note explaining that the user
    must press `→` after each occurrence. Less work; doesn't restore
    the auto-reminding behavior but at least the UI tells the truth.
  Option (a) is recommended — auto-advance is the smallest behavior
  change that matches the long-standing UI promise.
- **Risks / dependencies:** All three options touch
  `RootView.refreshRepeatReminders` and/or `NotificationService`. Option
  (a) writes back to SwiftData (advances dates), so make sure the save
  + `UpcomingSnapshotBuilder.writeSnapshot` combo runs once after the
  batch, not per task.

### N2. AboutSheets section titles and detail copy bypass localization

- **Severity:** High
- **Related files:** `Task/Views/Settings/AboutSheets.swift:6-12,14-20,49-69,72-107,116-227,337-376,409-422,447-487`
- **Description:** `AboutInfoSection` and `AboutGuideSection` declare
  every user-facing string as `String`:
  ```swift
  struct AboutInfoSection: Identifiable {
      let title: String
      let details: [String]
      ...
  }
  ```
  Render path inside `AboutInfoCard` / `AboutGuideCard`:
  ```swift
  Text(detail)                      // detail: String → Text<S: StringProtocol>
  ```
  This picks the `Text(_ content: S)` overload, which documents itself
  as "displays a stored string without localization." Two compounding
  effects:
  - Literals at the callsite (e.g. `title: "Create Tasks"`,
    `details: ["…tap the Notes area…"]`) are *not* auto-extracted into
    the catalog because the parameter type is `String`, not
    `LocalizedStringKey`.
  - Even for the few strings that *are* in the catalog (e.g. "Boards",
    "Search", "Appearance", "Data", "Disclaimer", "Copyright", "Email"
    — present because they appear elsewhere in `SettingsView`,
    `BoardSwitcherView`, etc.), the `Text(stringVar)` site bypasses the
    catalog lookup anyway.
  Catalog probe — present (extracted via other callsites) vs missing:
  - PRESENT: `"Boards"`, `"Search"`, `"Appearance"`, `"Data"`,
    `"Email"`, `"Disclaimer"`, `"Copyright"`, plus the inline
    `Text("© 2026 …")` and `Text("Task is a personal productivity
    app…")` in `CopyrightSheet` (extracted via the `Text(_ key:
    LocalizedStringKey)` overload because those use string literals
    directly).
  - MISSING: `"Create Tasks"`, `"Notes & Checklists"`,
    `"Organize the Board"`, `"Tags & Groups"`, `"Dates & Reminders"`,
    `"Defaults"`, `"Widget"`, `"Local-First Data"`, `"Network Access"`,
    `"Notifications"`, `"Your Control"`, and every detail/step
    paragraph on the How to Use, Privacy, and Disclaimer sheets.
  Net effect: a Chinese user opening Settings → About → How to Use
  sees most card titles and *every* explanatory paragraph in English,
  while the navigation bar, dismiss button, and the Settings rows that
  led here render in Chinese. Worst on the longest copy surface in the
  app.
- **Why it matters:** About → How to Use is the user-facing tutorial.
  About → Privacy is the user-facing privacy disclosure — a surface
  where a coherent translation matters for trust and (in some
  jurisdictions) compliance. Currently both ship English on Chinese
  builds.
- **Suggested fix:** Change the section properties to
  `LocalizedStringKey` and render them with `Text(localizedKey)`:
  ```swift
  struct AboutInfoSection: Identifiable {
      let id = UUID()
      let title: LocalizedStringKey
      let systemImage: String
      let tintColor: Color
      let details: [LocalizedStringKey]
  }
  ```
  Same shape for `AboutGuideSection.title` and `steps`. After the
  change, every existing literal in the
  `[AboutInfoSection]` / `[AboutGuideSection]` initializers auto-
  extracts and `Text(localizedKey)` looks up the catalog at runtime.
  Add the missing keys and their zh-Hans translations. The 16
  `extractionState: "manual"` entries currently in the catalog (see
  N5) are likely workarounds for this exact issue and can be retired
  once the parameter types flip.
- **Risks / dependencies:** Touches one file but adds ~50 catalog
  entries that need zh-Hans translations. The existing
  `testStringCatalogHasTranslatedZhHansForActiveKeys` test will gate
  the additions, so the build can't pass until they're translated.

### N3. `CURRENT_PROJECT_VERSION = 7` in pbxproj while README and VersionHistory say build 6

- **Severity:** Medium
- **Related files:** `task.xcodeproj/project.pbxproj` (search
  `CURRENT_PROJECT_VERSION`), `README.md:9`, `VersionHistory.md:3`
- **Description:**
  - `README.md` line 9: `Current app version: **0.4.7 (build 6)**`.
  - `VersionHistory.md` line 3: `## 0.4.7 (build 6) — 2026-05-23`.
  - `task.xcodeproj/project.pbxproj` (both `Task` and
    `TaskWidgetExtension` configs): `CURRENT_PROJECT_VERSION = 7;`.
  Most recent commit (`d0fda54 Prepare Task build 6 updates`) intended
  build 6, but the working tree's `task.xcodeproj/project.pbxproj` is
  modified (per `git status --short`) and now reads 7. The same drift
  the archive 04 N10 flagged when README sat at build 1 while pbxproj
  was at 4 — opposite direction this time.
- **Why it matters:** TestFlight and App Store rejections (or
  build-up-bumping mistakes during release) are an under-the-radar
  category of preventable problems. Independent of submission, a
  contributor reading the project sees three different "build" answers.
- **Suggested fix:** Decide which build this is. If shipping
  build 6 (as the docs say), revert the pbxproj bump. If the next
  release is build 7, update `README.md` and add a build 7 entry to
  `VersionHistory.md`. Same hygiene the prior audit flagged.
- **Risks / dependencies:** None. Verify CFBundleVersion in the
  generated Info.plist as well (the `GENERATE_INFOPLIST_FILE = YES`
  path uses `CURRENT_PROJECT_VERSION` directly).

### N4. VersionHistory build 6 entry omits three visible changes

- **Severity:** Low
- **Related files:** `VersionHistory.md:3-58`,
  `Task/Services/NotificationService.swift:16-64`,
  `Task/Components/CalendarPicker.swift:131-179,422-431`,
  `Task/Models/BoardGroup.swift:9,29-32,84-122`,
  `Task/Views/Board/GroupMenuSheet.swift:115-128`,
  `Task/Views/Board/TaskCardView.swift:48-66`
- **Description:** Three v0.4.7 build 6 changes ship in the code but
  aren't called out in `VersionHistory.md`'s build 6 entry:
  - **Repeating reminders no longer auto-recur** (see N1). Major
    behavior change worth a dedicated note so existing users who set
    "Daily" know what to expect.
  - **CalendarPicker gained a Clear button** beside Today
    (`CalendarPicker.swift:131-149` and the
    `CalendarPickerSelection.clear(...)` helpers). Visible new
    affordance.
  - **Per-status Cards per Column limit** (5 / 10 / 15 / 20 / All)
    moved from the global Card Order setting to a segmented control
    inside Edit Status / `GroupMenuSheet.cardDisplayLimitSection`. The
    storage is the new `BoardGroup.cardDisplayLimitRaw` field, also
    round-tripped through `GroupExport`.
  - **Repeat icon on cards.** `TaskCardView` now renders an
    `arrow.clockwise` icon in the card footer when `task.repeatRule
    != .none`. (Pairs with N1 — the icon implies recurrence the
    notification path no longer delivers.)
- **Why it matters:** VersionHistory is the user-visible release-notes
  surface and a common contributor reference. Missing entries hide
  behavior changes and obscure where to start when bisecting bug
  reports.
- **Suggested fix:** Add a "Repeat reminders" subsection to build 6
  documenting the new "manual advance" model (or whichever model lands
  for N1), and add the Calendar Clear button, the per-status Cards per
  Column move, and the card-footer repeat icon to the existing
  bulleted sections.
- **Risks / dependencies:** None.

### N5. Catalog has 16 `extractionState: "manual"` entries — workarounds for the same root pattern

- **Severity:** Low
- **Related files:** `Task/Localizable.xcstrings`
- **Description:** A `grep` over the catalog reports 16 entries with
  `"extractionState" : "manual"` — keys someone hand-added because the
  Swift source wasn't auto-extracting them. Spot check: the long
  About-sheet sentence
  `"Two boards can each have their own group called \"Doing\" — groups
  and tags don't cross boards."` is marked manual. Same shape as the
  literals at `AboutSheets.swift:163` (a `steps:` entry on the
  `Tags & Groups` `AboutGuideSection`). Without N2's fix, every
  hand-added manual entry only stays in sync as long as the source
  literal hasn't drifted; an edit to the literal silently breaks the
  lookup (the catalog key remains tied to the old text). Over time the
  manual count grows whenever a contributor patches an English typo
  and remembers to update the catalog.
- **Why it matters:** Maintainability — the catalog is meant to track
  source automatically. Manual entries are technical debt that the
  catalog test (which only checks `extractionState != "stale"`)
  doesn't surface as a problem.
- **Suggested fix:** Land N2 first. Most manual entries should then
  re-extract as `auto` entries; the catalog editor will surface any
  that don't have an obvious auto-extraction site, and those can be
  retired or reworked. Aim for zero manual entries.
- **Risks / dependencies:** Land after N2. Pruning before the
  parameter-type flip would just re-introduce the same gaps.

### N6. TaskCardView footer icons (repeat / notes / alarm) have no accessibility labels

- **Severity:** Low
- **Related files:** `Task/Views/Board/TaskCardView.swift:48-69`
- **Description:** Build 6 added the `arrow.clockwise` icon to the
  card footer alongside the existing `doc.text` (notes) and `alarm`
  (reminder) icons:
  ```swift
  if task.repeatRule != .none {
      Image(systemName: "arrow.clockwise")
          .font(.caption2)
          .foregroundStyle(.secondary)
  }
  ```
  None of the three carries an `.accessibilityLabel`. VoiceOver reads
  the SF Symbol's default name (something like "arrow clockwise",
  "doc text", "alarm") — not the meaning ("repeats", "has notes",
  "has reminder"). Adjacent surfaces do label their icons (e.g.
  `TaskCardView.checkboxControl.accessibilityLabel("Mark task done")`,
  the `BoardDateSliderDateTile.accessibilityLabel(...)`).
- **Why it matters:** VoiceOver users currently get noise instead of
  semantic information. Three icons share one row, so the order matters
  and the labels are the only signal.
- **Suggested fix:** Wrap each icon in `.accessibilityLabel(...)` with
  a `LocalizedStringKey` ("Repeats", "Has notes", "Has reminder").
  Add the three keys to the catalog. If the footer row is meant to be
  a single accessibility element, set `.accessibilityElement(children:
  .combine)` on the outer `HStack` and craft a combined label like
  "Repeats. Has notes. Has reminder."
- **Risks / dependencies:** None.

### N7. The `→` repeat-advance affordance is hidden inside the editor sheet

- **Severity:** Low
- **Related files:** `Task/Views/Task/TaskDetailView.swift:353-395`
- **Description:** Now that "Repeat" is a date-advance convenience
  (see N1), the only way to advance the task's working / due dates by
  one rule is to open the editor and tap the `→` chip on the Repeat
  row. There's no card-level affordance, no swipe action, no
  notification action ("Advance to next occurrence"), and no
  app-lifecycle auto-advance (`RootView.refreshRepeatReminders` just
  re-schedules without advancing). The card already shows the
  `arrow.clockwise` icon to indicate the task repeats — a swipe or
  long-press on that icon could trigger advancement without opening
  the editor.
- **Why it matters:** Discoverability — users who don't open the
  editor will never advance the dates. Pairs with N1: even if N1 is
  fixed by auto-advance on scene-active, exposing a manual gesture
  helps power users (advance immediately after acknowledging the
  reminder, regardless of where the date is).
- **Suggested fix:** Three options, pick what fits the design language:
  - (a) Add a notification action category with an "Advance" action
    that calls `advance(_:)` on the task and re-schedules the next
    occurrence.
  - (b) Long-press the `arrow.clockwise` icon in the card footer to
    advance the dates with a brief haptic + animation.
  - (c) Add an "Advance" swipe action on the card itself.
  Any of these is a small addition; the editor route stays as the
  canonical path.
- **Risks / dependencies:** None for the local affordance options.
  The notification-action option adds a small `UNNotificationAction`
  registration in `TaskApp.onAppear` / `NotificationService` and a
  `UNUserNotificationCenterDelegate` hook to handle the action.

### N8. `DataStorageSummary.displayText` interpolates raw `String` count into the inflection key

- **Severity:** Low
- **Related files:** `Task/Services/DataImportExport.swift:248-265`,
  `Task/Localizable.xcstrings` (key `item` / `items`)
- **Description:** `DataStorageSummary.displayText` composes the
  Storage Check row's value as:
  ```swift
  let itemLabel = itemCount == 1 ? String(localized: "item") : String(localized: "items")
  return "\(itemCount) \(itemLabel) / \(Self.formatBytes(byteCount))"
  ```
  Two issues stack:
  - The result is a raw `String` returned from a model method; the
    callsite (`SettingsView.storageCheckValue`) passes it to
    `Text(value)` via the `SettingsButtonRow`'s `trailing(value:
    String)` adapter, which uses `Text(_: S)` — already non-localized.
    But the `String(localized:)` calls inside `displayText` *do*
    localize "item" and "items" before composition, so the user sees
    "12 items / 24 KB" with `items` localized.
  - The inflection (`item` vs `items`) is handled by the manual
    `count == 1` branch instead of SwiftUI's `^[\(n) item](inflect:
    true)` markup. For English that's equivalent; for any future
    locale with non-trivial plural rules (one, few, many), the manual
    branch loses information. Same point archive 02 N10 raised.
- **Why it matters:** Minor — pluralization quality. zh-Hans has no
  plural forms so the current output renders correctly today; the
  cost is that the implementation diverges from the
  inflection-markup pattern used elsewhere in the codebase
  (`StatusPickerSheet`, `TagPickerSheet`, `RepeatPickerSheet`,
  `DataImportExport.successMessage`).
- **Suggested fix:** Replace the manual branch with
  `String(localized: "^[\(itemCount) item](inflect: true)")` and let
  Foundation pick the right form. Drop the `items` catalog key after.
  Or — since the value flows through `Text(...)`, build the full
  string as a `LocalizedStringResource` and let `Text` do the
  formatting:
  ```swift
  Text("^[\(itemCount) item](inflect: true) / \(Self.formatBytes(byteCount))")
  ```
- **Risks / dependencies:** None. The display call site stays
  unchanged.

### N9. `defaultExportFileName()` builds a 24-hour timestamp regardless of `Settings → Time Format`

- **Severity:** Low
- **Related files:** `Task/Services/DataImportExport.swift:675-679`
- **Description:** `defaultExportFileName()` returns
  `"task-export-\(formatter.string(from: Date()))"` with
  `formatter.dateFormat = "yyyy-MM-dd-HHmm"`. The 24-hour `HH` is
  fine as a filename pattern (filenames shouldn't localize), but the
  date is rendered in the device locale rather than
  `TaskDateFormat.locale`. Mixed-locale users could see surprising
  results (Buddhist / Japanese calendar device users would have the
  year drift if the device calendar is non-Gregorian). The current
  approach is acceptable for an export filename; flag this only as a
  follow-up if `Settings → Language` ever needs to drive export
  filenames too.
- **Why it matters:** Minor / pre-emptive.
- **Suggested fix:** Set `formatter.calendar = Calendar(identifier:
  .gregorian)` and `formatter.locale = Locale(identifier: "en_US_POSIX")`
  to guarantee a stable, machine-parseable timestamp regardless of
  device locale. Defensive change; no user behavior delta today.
- **Risks / dependencies:** None.

### N10. "iCloud Sync — Coming Soon" row carries from v0.1.0; still no implementation

- **Severity:** Low
- **Related files:** `Task/Views/Settings/SettingsView.swift:280-287`,
  `LessonsLearned.md:631-639`
- **Description:** Settings → Data → iCloud Sync renders with a
  "Coming Soon" trailing value and dimmed styling
  (`SettingsRowLabel(..., dimmed: true)`). The placeholder dates back
  to v0.1.0 and is still unwired. `LessonsLearned.md`'s "Things to do
  later" section lists iCloud sync first, but the row's visible
  promise has been live for multiple releases. The schema is already
  CloudKit-ready (LessonsLearned confirms "every property has a
  default … no `@Attribute(.unique)` … optional inverse relationships")
  — only the model configuration flip and entitlement remain.
- **Why it matters:** Reads as a known long-deferred feature, which
  is acceptable, but "Coming Soon" should either ship or get reframed
  so it doesn't look like the team forgot about it.
- **Suggested fix:** Either:
  - (a) Ship it: flip `ModelConfiguration` to `cloudKitDatabase:
    .private`, add the CloudKit entitlement, validate the schema does
    not regress. Tracked in `Things to do later`.
  - (b) Reframe the row to hide it from the main Settings surface
    until ready, or change the trailing label to "Planned" / move it
    to About → How to Use roadmap.
  Skip if shipping it is the genuine plan and that ship is near.
- **Risks / dependencies:** Option (a) is a multi-PR effort with
  full migration testing.

---

## 3. Code quality findings

- **Duplicated code:**
  - 26+ sites still call `try? context.save()` directly; 15+ of them
    also call `UpcomingSnapshotBuilder.writeSnapshot(from: context)`
    immediately after. The remaining sites correctly skip the
    snapshot (tag-color tweaks, reorder snapshots). A
    `BoardWriter.save(context:writeSnapshot:Bool = true)` helper
    would funnel both lists through one site and make a future
    debounce of `WidgetCenter.reloadAllTimelines()` land cleanly.
    Same point archive 02 N14 raised; still applies.
  - `ColorKey` (Task target) and `WidgetColorKey` (TaskWidgetExtension
    target) re-declare the same seven RGB tuples and `hue`/
    `background` accessors. Must be updated in lockstep. Could share
    via a synchronized-folder inversion now that the widget catalog
    proved the cross-target sharing pattern works.
  - `SharedDefaultsService.UpcomingSnapshotEntry` and
    `WidgetUpcomingEntry` describe the same JSON shape with the
    `boardID`/`boardEmoji`/`boardTitle` and `groupID`/`groupSortIndex`
    fields optional on the widget side (to tolerate older snapshots)
    and required on the app side. Field-name agreement is currently
    maintained by hand — pairs with `ColorKey` / `WidgetColorKey`.
  - `WidgetStatusListEntry` (widget) mirrors
    `SharedDefaultsService.StatusListEntry` (app). Same pattern.

- **Unused or outdated files / symbols:**
  - None observed. The catalog reports 0 stale keys, no production
    `TODO`/`FIXME`/`XXX`, no `print(` calls, no `try!` / `as!` /
    `force unwrap` patterns in production code (`SwiftDataManager`
    has only a `fatalError` after a logged double-failure, which
    is intentional).

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` is 763 lines (was 758 in
    archive 04). Same split candidates as before: extract the
    `workingDateSheet` / `dueDateSheet`, the seven property rows,
    the `AppTextSize.taskDetail*Size` private extension, and the
    bottom action row into companion files.
  - `Task/Views/Task/MarkdownNotesEditor.swift` is 501 lines (was
    461). New parser additions in build 6 push the file further. The
    parser (`parseNoteLines`, `matchHeading`, `matchBareTask`,
    `matchBulletOrTask`, `matchTaskBody`, `toggleTaskMarker`,
    `toggleTaskBox`, `taskMarkerLength`, `applyLineMarkdownStyles`,
    `applyInlineMarkdownStyles`) is pure-function and would read
    better in its own `MarkdownNotesParser.swift`.
  - `Task/Services/DataImportExport.swift` is 681 lines (was 537).
    `mergeBoard(_:into:plan:)` is ~180 lines that walk groups, tags,
    and tasks merge in a single method. Extracting `mergeGroups`,
    `mergeTags`, `mergeTasks` would keep future plan-adjustment work
    small and focused.
  - `Task/Views/Settings/AppearanceView.swift` is 487 lines and
    still bundles the `FlatSettingsChoicePicker` family with the
    standalone `ReminderTimePickerSheet` keypad. Splitting the
    keypad sheet into its own file would let `AppearanceView`
    shrink to the picker family it advertises.

- **Naming inconsistencies:**
  - `task.activeBoardID` raw UserDefaults key string is still
    referenced at `RootView.swift:10` and at
    `DataImportExport.swift:656` with no central constant. Carry-over
    from archive 04.

- **Structural improvements:**
  - Centralize the `try? context.save()` + `writeSnapshot` pair
    behind a `BoardWriter.save(context:)` helper.
  - Move the cross-target color palette and the cross-target snapshot
    entry types into shared source-only files referenced via
    `PBXFileSystemSynchronizedBuildFileExceptionSet` inversions.
    The new widget catalog (`TaskWidgetExtension/Localizable.xcstrings`)
    proves the synchronized-folder file-sharing pattern works for new
    cross-target files.
  - Make the SwiftUI custom views consistent about their string
    parameter type: prefer `LocalizedStringKey` for any user-facing
    text parameter so callsite literals auto-extract and runtime
    rendering localizes. `AboutInfoSection` / `AboutGuideSection` are
    the remaining offenders (see N2).

---

## 4. Functional issues

- **Boards** — Default seed (Personal / Study / Work) covered by
  `testSeedCreatesThreeDefaultBoards`. Add board through the switcher
  works. Board reorder via long-press drag works via the shared
  `ReorderDropDelegate<Board>`. Delete via expanded sheet → delete
  mode → confirmation works; cascades through tasks and cancels their
  reminders.
- **Board / columns / cards** — Pagination, `.id()` re-render on sort
  change, pull-to-refresh, cross-column drag-reorder, drag rollback
  watchdog, "More · N left" chip all work. The new per-status `Cards
  per Column` segmented control on `GroupMenuSheet` writes
  `BoardGroup.cardDisplayLimitRaw` and `ColumnView` reads it via
  `cardDisplayLimit.initialVisibleCount(totalCount:)`.
- **Per-task checkbox** — Toggle from the card title row (when
  `showsCheckbox`) and from the editor's Checkbox toggle row works.
  Editor's `task.isChecked = showsCheckbox && isChecked` save defends
  against a dangling `isChecked = true` after the user hides the
  checkbox. Widget now correctly drops checked tasks via
  `UpcomingSnapshotBuilder.writeSnapshot`'s
  `if task.showsCheckbox && task.isChecked { return nil }`.
- **Drag and drop** — Cross-column drops save once via
  `placeTask(commit: true)`. Within-column live drag yields smoothly.
  Drop proposal `.move` everywhere — no green `+` badge. Reorder
  rollback watchdog covers BoardSwitcher / StatusPicker / TagPicker
  via the consolidated `ReorderDropDelegate`.
- **Swipe to edit** — New `SwipeToEditRow` wraps each status / tag
  row. Horizontal-left swipe reveals an "Edit" pill; releasing past
  the trigger distance opens the existing edit sheet. Disabled in
  delete mode. Threshold logic
  (`SwipeToEditRowMetrics.shouldOpenEdit(for:)`) tested by
  `testSwipeToEditMetricsMoveRowsOnlyForHorizontalLeftSwipes`.
- **Board date slider** — Generates a contiguous day window from the
  union of task-derived dates and the focus day, capped to plus/minus
  one year around today (covered by
  `testBoardDateSliderWindow*` tests). Recenters on open via the
  `dateFilterOpenToken` and the `scrollPosition = nil` then
  re-assign pattern. Locale uses `TaskDateFormat.locale`.
- **CalendarPicker (new Clear button)** — Today button works.
  Range mode after both endpoints are set: tapping start swaps end
  into start and clears end; tapping a third date starts a fresh
  selection. New Clear button nils the selection in single mode and
  both endpoints in range mode
  (`CalendarPickerSelection.clear(...)` helpers, covered by
  `testCalendarPickerClearSingleDateSelection` /
  `testCalendarPickerClearRangeSelection`).
- **Search** — Cross-board search works; active board surfaces first.
  Computes `groupedResults` once per render to avoid double-filter
  cost. Empty / no-match states use `ContentUnavailableView`.
- **Default Status picker** — Default Status set via the Default for
  New Tasks toggle inside the per-group **Edit Status** sheet
  (`GroupMenuSheet`). New-task sheet uses `board.defaultGroup` which
  falls back to `orderedGroups.first`. "Current default: …" line uses
  `String(localized: "None")` for empty fallback. Tested by
  `testBoardDefaultGroupToggleSetsAndMovesDefaultWhenDisabled`.
- **Status / Tag picker management** — Done via `StatusPickerSheet`
  and `TagPickerSheet`. Both use the consolidated
  `ReorderDropDelegate`. Swipe-left to reveal Edit
  (`SwipeToEditRow`). Delete-mode toggle is consistent across both.
- **Task editor** — Title field uses `TextField(prompt:)`. Seven
  property rows (Status / Tags / Working / Due / Repeat / Checkbox /
  Reminder). New checkbox row toggles `showsCheckbox`. Reminder
  anchor badge mirrors `TaskItem.primaryReminderDate`. Repeat advance
  `→` shifts every set date forward by one occurrence
  (accessibility label reads "Advance to next occurrence" — N7 from
  archive 04 fixed). Duplicate Task action via the bottom row +
  `ConfirmationSheet`. Save's "past fire time today" branch shows an
  inline warning before save so the silent clear isn't a surprise.
- **Repeat options** — biweekly, quarterly, and annually covered by
  `testBiweeklyRepeatAdvancesByTwoWeeks` and
  `testQuarterlyAndAnnuallyRepeatAdvanceByExpectedIntervals`. **The
  rules now only control date advancement (see N1)**; the
  `NotificationService` notification is a single one-shot, not a
  recurring schedule.
- **Markdown notes** — `MarkdownNotesEditor` supports headings, bold,
  italic, bullets, checklists with all four prefix shapes (`- [ ]`,
  `- []`, `[ ]`, `[]`, plus checked variants). Editor styles markdown
  live while keeping markers visible. Tests cover all the shapes.
- **Card notes preview** — Driven by `settings.notesPreview` enum;
  shows 0/1/2/3 lines depending on the setting. Parses the same
  shapes as the editor (covered by
  `testCardNotesPreviewParsesTaskLinesAsTypedRows` /
  `testCardNotesPreviewPreservesLeadingIndentationForTextAndTasks`).
- **Import / Export / Reset** — Round-trips correctly for self-
  exported data. `showsCheckbox`, `isChecked`, and the new
  `cardDisplayLimitRaw` are round-tripped with `decodeIfPresent` for
  backward-compat (covered by
  `testTaskExportDecodesCheckboxFieldsAndDefaultsLegacyPayloadsToOff`
  and `testGroupExportDefaultsLegacyCardDisplayLimitToFive`). Orphan
  counts surface via the format-string + manual-singular path
  (covered by `testImportSuccess*` tests). Reset shows a
  `ProgressOverlay` and yields every 50 tasks during the cancel /
  re-seed loops.
- **Storage Check** — `SettingsView.checkStorage()` calls
  `DataImportExport.storageSummary(context:)` which fetches each
  model type, encodes a `MultiBoardExportPayload` to estimate bytes,
  and renders the result inline. Covered by
  `testStorageSummaryCountsAppDataModelsAndExportBytes`.
- **Notifications** — `schedule(for:)` builds a *single*
  `UNCalendarNotificationTrigger` at the task's
  `primaryReminderDate`, time-of-day from `board.reminderMinutesOfDay`
  (or `ReminderDefaults.defaultMinutesOfDay` if no board). Past-date
  guard skips occurrences before now. Authorization-denied state
  surfaces a banner. Repeat is **no longer notification recurrence**
  (see N1). The `cancel(for:)` path still cleans up legacy 16-batch
  identifiers (`task.id@1`…`task.id@15`) so post-upgrade installs
  don't keep receiving stale future repeats.
- **Widget board filter** — Works. Filtering by board reads
  `entry.boardID == config.board?.id`.
- **Widget status filter** — Works for valid combinations. When the
  user picks a status whose `boardID` doesn't match the configured
  `board.id`, the filter drops the status condition (so the widget
  surfaces the board's tasks instead of locking into permanent "No
  upcoming"). N6 from archive 04 fixed.
- **Widget background style** — Three options (System Default / Pure
  Black / Pure White) wired through `BoardConfigurationIntent.background`.
- **Localization** — App catalog covers 248 / 248 keys in zh-Hans
  (100%, 0 stale). Widget catalog covers 17 / 17 keys
  (100%). The `testStringCatalogHasTranslatedZhHansForActiveKeys`,
  `testTaskEditorVisibleLabelsAreActiveInStringCatalog`, and
  `testWidgetStringCatalogIncludesMetadataKeys` tests gate the
  invariants. The remaining gap is the AboutSheets surface (N2),
  whose literals never reach the catalog at all.

---

## 5. UI/UX issues

- **N1 (Repeating reminders only fire once)** — Major UX regression
  from previous build. UI labels promise behavior the notification
  path no longer delivers.
- **N2 (AboutSheets bypass localization)** — Most About copy renders
  English on Chinese builds.
- **N6 (Card footer icons missing labels)** — VoiceOver users hear
  symbol names, not meaning.
- **N7 (Advance affordance hidden in editor)** — Discoverability gap
  for the new "manual advance" model.
- **Drag preview shapes** — All card surfaces use
  `.contentShape(.dragPreview, RoundedRectangle(cornerRadius: …))` /
  `Capsule(...)` for the group pill. No green `+` anywhere.
- **iOS 26 fallback parity** — `BottomNavBar` forks via `#available
  (iOS 26.0, *)`; the iOS 18-25 fallback uses `.thinMaterial` +
  `secondarySystemBackground` circles with the same control set.
- **ConfirmationSheet fixed height** — `confirmationSheetPresentationStyle()`
  pins the detent to 360 pt. The Reset confirmation copy is the
  longest message anywhere; at very large Dynamic Type sizes it could
  press against the buttons. Same caveat as archive 04; needs on-device
  verification.
- **MarkdownNotesEditor blank-line tap target** — `Color.clear` with
  `frame(height: 8)` and `onTapGesture { beginEditing() }`. Narrow
  hit target; carries over from prior audits.
- **`ProjectHeaderView` icon button asymmetry** — Sort icon stays
  neutral even when sort is not Manual. Date Filter icon tints when
  the filter is active. Minor consistency issue.

---

## 6. Data and persistence issues

- **Cascade deletes** — `Board.groups` / `tags` / `tasks` all set
  `deleteRule: .cascade`. `BoardGroup.tasks` uses `.nullify`. Live
  delete paths reassign tasks to the fallback group before deleting;
  the cascade-from-Board path deletes everything anyway, so no orphan.
- **CloudKit-readiness invariants** — Every `@Model` property in
  `Board`, `BoardGroup`, `TaskTag`, `TaskItem` has a default value,
  no `@Attribute(.unique)`, optional inverse relationships. New
  `BoardGroup.cardDisplayLimitRaw` defaults to `CardDisplayLimit.five
  .rawValue` so SwiftData lightweight migration handles the v0.4.7
  build-6 upgrade.
- **`TaskItem.duplicated(sortIndex:)`** copies every editable field
  including `showsCheckbox` and `isChecked`. Tested by
  `testTaskDuplicateCopiesEditableFieldsAndRelationships`. Same UX
  open question as archive 04 — should `isChecked = true` survive a
  duplicate? Probably worth a small product decision; current
  behavior preserves the source's check state.
- **In-memory fallback signal** — `RootView` surfaces the alert
  exactly once per launch. `resetAll` purges the on-disk store files
  when in fallback so the next launch can rebuild cleanly.
- **Snapshot encoding** — Both write paths use `.iso8601`; widget
  decoder matches. App-side and widget-side entry types differ in
  optionality on purpose (older snapshots).
- **`writeBoardList` / `writeStatusList` use default JSONEncoder()**
  — `SharedDefaultsService.swift:66-72,81-87`. Neither entry type
  carries `Date` fields today so this is benign; if any are added,
  mirror the `.iso8601` rule.
- **Export ordering** — `BoardExportEntry.tasks` are written in
  natural `(board.tasks ?? [])` order; round-trip still works because
  `sortIndex` is persisted, but exports are not byte-identical
  across runs.
- **Save-failure paths** — `TaskDetailView.save / delete / duplicate`
  and `DataImportExport.importData` all `try context.save()` with
  `context.rollback()` on failure plus an early `dismiss()`. The
  `NotificationPlan` shape inside `DataImportExport` defers
  cancellation + re-schedule until *after* the save commits, so a
  failed import can't strand the user with cancelled-but-not-replaced
  reminders.
- **`task.activeBoardID` UserDefaults key** — still not centralized;
  see §3 naming inconsistencies. Read by `RootView.swift:10`,
  cleared by `DataImportExport.swift:656`.

---

## 7. Configuration and platform issues

- **N3 (Version drift)** — `task.xcodeproj/project.pbxproj` shows
  `CURRENT_PROJECT_VERSION = 7` while `README.md` and `VersionHistory.md`
  say build 6.
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
- **Widget localization** — `TaskWidgetExtension/Localizable.xcstrings`
  ships with the widget target. N4 from archive 04 fixed.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  remains excluded; everything else under the synchronized roots
  picks up its target automatically.
- **Alternate icons** — `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES
  = "Rose Violet Midnight Neutral Light"` matches
  `AppIconOption.alternateName`.
- **Swift 5.0** — pinned in every target's `SWIFT_VERSION`.
- **Portrait-only, iPhone-only** — unchanged.

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - **Repeating reminder behavior on scene-active.** The new one-shot
    model means a "Daily" reminder goes silent after one occurrence
    unless the user manually advances. A test that constructs a task
    with `repeatRule = .daily` and a past `primaryReminderDate`, runs
    `RootView.refreshRepeatReminders`-style logic, and asserts the
    behavior locks in the current contract. If N1 is fixed by
    auto-advance, the same test asserts the new contract — either
    way, this is the highest-risk untested code path.
  - `BoardGroup.cardDisplayLimit` Picker — the segmented control
    persists to `cardDisplayLimitRaw` and `ColumnView` re-renders on
    change. The model-side default is tested
    (`testBoardGroupCardDisplayLimitDefaultsToFiveAndSupportsAllChoices`)
    but the UI binding isn't.
  - `CalendarPicker` Clear button — both helper functions
    (`CalendarPickerSelection.clear(...)`) are tested; the button's
    `disabled(!hasSelection)` UI state and the range-mode reset
    semantics aren't.
  - `SwipeToEditRow` accessibility — the threshold metric is tested
    (`testSwipeToEditMetricsMoveRowsOnlyForHorizontalLeftSwipes`);
    the VoiceOver labels (`accessibilityLabel("Edit")`) and the
    `Label("Edit", systemImage: "pencil")` rendering aren't.
  - `AboutSheets` localization — once N2 lands, add a test that
    instantiates the `AboutGuideSection` array and asserts the
    sectioned literals resolve against `Localizable.xcstrings`'s
    zh-Hans column.

- **Suggested tests:**
  - `testRepeatRuleFireDatesEmptyAfterOccurrenceElapses()` — anchor
    a task at yesterday, repeat = daily, hasReminder = true. Assert
    `NotificationService.fireDates` returns `[]`. Locks in N1's
    current behavior.
  - `testRepeatReminderAutoAdvancesOnSceneActive()` — after a fix for
    N1, assert that running the scene-active refresh on a stale
    repeating task advances its dates and schedules the next ring.
  - `testAboutSheetTitlesAndDetailsAreInStringCatalog()` — once N2
    flips the parameter types, enumerate every section's literal and
    assert each key is present and `state == "translated"` in zh-Hans.
  - `testWidgetStatusFilterDropsCrossBoardStatus()` — assert the
    `effectiveStatus` guard in `UpcomingTasksProvider.filter` drops a
    status from a different board.
  - `testTaskCardViewFooterIconsHaveAccessibilityLabels()` — once
    N6 lands, snapshot or accessibility-tree verify the labels.

- **Manual / device-only:**
  - Reproduce N1 on-device: set a daily repeating reminder, observe
    that only one ring arrives.
  - Reproduce N2: switch the app to Chinese, open Settings → About →
    How to Use / Privacy / Disclaimer; verify the section titles and
    paragraphs render English.
  - Verify the widget refreshes promptly after task edits in a real
    widget install across all three families (with the new cross-
    board status filter and the new background-style options).
  - Confirm `setAlternateIconName` actually swaps app icons on iOS 18
    and iOS 26.
  - VoiceOver pass over the new bottom action clusters (Delete Task +
    Duplicate Task; Delete a Status + Add a Status; Delete a Tag +
    Add a Tag), the swipe-to-edit action on rows, the date slider
    tiles, the calendar picker Clear button, and the Markdown
    checkbox rows.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — Decide the repeating-reminder model and either restore
    auto-fire behavior or surface the new manual-advance contract in
    the UI. Highest user impact; affects everyone using repeats.
  - **N2** — Change `AboutInfoSection.title` / `details` and
    `AboutGuideSection.title` / `steps` to `LocalizedStringKey` and
    add the ~50 new keys with zh-Hans translations. Largest remaining
    Chinese-build localization gap.
  - **N3** — Reconcile pbxproj `CURRENT_PROJECT_VERSION` with README
    and VersionHistory before the next ship.
- **Fix next:**
  - **N4** — Backfill the build 6 VersionHistory entry with the
    repeat-behavior change, the Calendar Clear button, the per-status
    Cards per Column move, and the card-footer repeat icon.
  - **N6** — Label the three card-footer icons for VoiceOver.
  - **N7** — Expose advance outside the editor (notification action,
    long-press, or swipe). Bundle with N1 if N1 is fixed by surfacing
    the manual model.
- **Optional cleanup:**
  - **N5** — Retire the 16 manual catalog entries after N2 lands.
  - **N8** — Switch the Storage Check `items` plural to inflection
    markup.
  - **N9** — Pin `defaultExportFileName()` to a stable Gregorian
    POSIX timestamp.
  - **N10** — Decide the iCloud Sync row's future: ship it or
    reframe.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- `docs/Issues-cc-04.md` cross-referenced against current code for
  every prior issue. N1-N11 from archive 04 all confirmed resolved:
  `ConfirmationSheet` parameters are `LocalizedStringKey`,
  `SettingsButtonRow` / `SettingsRowLabel` / `SheetActionButtonLabel`
  titles are `LocalizedStringKey`, `StatusPickerSheet.sheetTitle` /
  `TagPickerSheet.sheetTitle` are `LocalizedStringKey`, widget target
  ships its own catalog with all 17 keys translated, snapshot drops
  `showsCheckbox && isChecked` tasks, `UpcomingTasksProvider.filter`
  drops cross-board status, accessibility label reads "Advance to
  next occurrence", repeat picker uses `^[\(count) task](inflect:
  true)`, catalog has 0 stale keys, `notesPreviewKey` migrated.
- `docs/Issues-cc-03.md` cross-referenced for archive-level
  carryovers.
- All Swift sources under `Task/`:
  - Models (`Board`, `BoardGroup` with the new
    `cardDisplayLimitRaw` field and `CardDisplayLimit` enum,
    `TaskTag`, `TaskItem`, `ColorKey`, `RepeatRule` with all six
    rules).
  - Services (`SwiftDataManager` with the in-memory fallback +
    `purgePersistentStoreFiles`, `NotificationService` with the new
    one-shot behavior, `SharedDefaultsService` with the optional
    snapshot fields, `UpcomingSnapshotBuilder` with the
    showsCheckbox/isChecked filter and `sortedEntries`,
    `DataImportExport` with the v2 wire format and `DataStorageSummary`).
  - Utils (`AppInfo`, `DateFormatters`).
  - ViewModels (`SettingsViewModel`) including the new dual-key
    `notesPreview` migration.
  - Views: `RootView`, board (`BoardView` + `BoardDateSlider` +
    `BoardDateSliderDayWindow`, `BoardSwitcherView`, `ColumnView`,
    `GroupMenuSheet` with the new Cards per Column section,
    `ProjectHeaderView`, `TaskCardView` with the new checkbox +
    repeat-icon footer, `BoardIconPickerSheet`), task
    (`TaskDetailView` with the new Checkbox row + inline reminder
    warning + Duplicate Task action, `MarkdownNotesEditor` +
    `LiveMarkdownTextView` + parser, `RepeatPickerSheet`,
    `StatusPickerSheet` and `TagPickerSheet` with swipe-to-edit and
    the consolidated `ReorderDropDelegate`), search (`SearchView`),
    settings (`SettingsView` with the new Date Filter / Date Format /
    Notes Preview / Reminder Time / Storage Check rows,
    `AppearanceView` + `ReminderTimePickerSheet`, `CardOrderPickerSheet`,
    `IconPickerSheet`, `ManualControlSheet`, `AboutSheets`).
  - Components (`BottomNavBar`, `CalendarPicker` with new Clear
    button, `CardBackground`, `ColorSwatchPicker`, `ConfirmationSheet`,
    `DateRow`, `FlowLayout`, `GridTile`, `GroupHeaderPill`,
    `ProgressOverlay`, `ReorderDropDelegate`, `SettingsCard`,
    `StringMoveDropDelegate`, `TagChip` + `SwipeToEditRow` +
    `SwipeToEditRowMetrics`).
- All Swift sources under `TaskWidgetExtension/`
  (`TaskWidgetBundle`, `UpcomingTasksProvider` with the cross-board
  status filter guard, `UpcomingTasksWidget` with the
  `WidgetBackgroundStyle` modifier, `WidgetSnapshot` with the
  optional snapshot fields and `WidgetStatusListEntry`,
  `BoardConfigurationIntent`).
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/PrivacyInfo.xcprivacy`,
  `TaskWidgetExtension/Info.plist`.
- `Config/Signing.xcconfig` and `task.xcodeproj/project.pbxproj`
  — build settings, synchronized folder exceptions, code signing,
  marketing / current version, INFOPLIST keys, bundle IDs, asset
  catalog config.
- `Task/Localizable.xcstrings` — programmatic count: 248 total
  keys, 0 stale, 248 zh-Hans `state: "translated"` (100%). 16
  entries marked `extractionState: "manual"` (see N5).
- `TaskWidgetExtension/Localizable.xcstrings` — programmatic count:
  17 total keys, all active, all zh-Hans translated.
- `TaskTests/TaskTests.swift` (35 tests covering the new
  `testRepeatingReminder*`, `testBoardGroupCardDisplayLimit*`,
  `testGroupExportDefaultsLegacyCardDisplayLimitToFive`,
  `testCalendarPickerClear*`,
  `testNotesPreviewUsesNewStorageKeyAndFallsBackToLegacyKey`,
  `testSwipeToEditMetricsMoveRowsOnlyForHorizontalLeftSwipes`,
  `testTaskEditorVisibleLabelsAreActiveInStringCatalog`,
  `testWidgetStringCatalogIncludesMetadataKeys`,
  `testLiveMarkdownEditingStyle*`).
- Grep queries (via `grep -rn ... --include='*.swift'`):
  - `TODO|FIXME|XXX` (no production matches).
  - `try!|as!|force unwrap` (no production force-unwraps; only a
    comment in `SwiftDataManager`).
  - `print(` (no production matches).
  - `MARKETING_VERSION|CURRENT_PROJECT_VERSION` in pbxproj (surfaced
    N3).
  - `extractionState` in `Localizable.xcstrings` (16 manual entries —
    see N5; 0 stale).
  - `SwipeToEditRow\b` (definition in `TagChip.swift:41`).
  - `ConfirmationSheet|confirmLabel|LocalizedStringKey` (verifying
    archive 04 N1 fix).
  - `SheetActionButtonLabel|SettingsButtonRow|SettingsRowLabel`
    (verifying archive 04 N2 fix).
  - `navigationTitle` and `sheetTitle` (verifying archive 04 N3 fix).
  - `String(localized:` in `TaskWidgetExtension/` (verifying archive
    04 N4 fix).
  - `showsCheckbox && isChecked` (verifying archive 04 N5 fix).
  - `effectiveStatus|status.boardID != boardID` (verifying archive 04
    N6 fix).
  - `Advance to next occurrence` (verifying archive 04 N7 fix).
  - `inflect: true` (verifying archive 04 N9 fix).
  - `task.notesPreview\b|task.notesPreviewEnabled` (verifying
    archive 04 N11 fix).

## Not checked (worth a follow-up)

- Live runtime behavior on iOS 18.x vs iOS 26 devices / simulators
  (Liquid Glass parity, alternate icon transitions, drag previews,
  the board date slider scroll-position recentering on dataset
  changes, ConfirmationSheet copy at extreme Dynamic Type sizes).
- On-device notification delivery — particularly the new
  one-shot behavior for repeating reminders (does the daily reminder
  fire on time, then truly stop?) — and authorization-denied paths.
- Instruments / memory profile for a board with thousands of tasks;
  the new Storage Check row's `DataImportExport.exportData` round-
  trip cost; the cost of re-encoding the export-bytes summary just
  to display a file size.
- Widget rendering under each `WidgetFamily` on a real device, the
  configuration intent picker after a board rename / icon change,
  and the `WidgetBackgroundStyle` options.
- Asset catalog contents — that the alternate icons
  (`Rose/Violet/Midnight/Neutral/Light`) and their `*Preview`
  siblings actually exist; the catalog isn't part of this audit.
- Verification that `Text(stringVar)` for a `String`-typed
  variable bypasses catalog lookup in the current SwiftUI runtime
  (this audit reasons from documented behavior and the Python
  catalog probe but does not execute the app on a Chinese-locale
  device to confirm N2's user-visible effect).
- Accessibility audit (Dynamic Type extremes, VoiceOver labels
  beyond N6, hit targets, drag-and-drop accessibility).
- `TestData/testdata*.json` integrity — not diff-walked.
- The git working tree has 14 modified files (per `git status
  --short`) that are unstaged at the time of audit; the audit reads
  the current on-disk state, which includes those edits. If any are
  reverted or refined before commit, re-run the audit.
