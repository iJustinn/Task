# Task — Issues Report

Audit of branch `task-v0.4.6` on 2026-05-22. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.4.6 (build 4 in `project.pbxproj`, documented as build 3 in README
and VersionHistory) is in good shape. Almost every item from
`docs/IssuesArchive-02.md` — the Default Status entry point, Reset copy,
HowToUseSheet paths, ManageGroupsView/ManageTagsView orphan files, locale
propagation in `TaskDateFormat`, `DefaultStatusPickerSheet` reachability,
`BoardIconPickerSheet` Cancel semantics, reset progress overlay, iCloud
Sync row dimming, repeat reminder scheduling, the `mediumWithTime`/
`isSameDay` dead code, the `TooMuchToDo`/`Work Harder Play Harder`
defaults, the orphan-message pluralization, and the import-result counts —
has been resolved. The remaining live issues are smaller. The highest-
impact gaps are: (a) `settings.dateFormat` is honored only on board cards
via `DateRow`/`DueDateRow`; `TaskDetailView`, `SearchView`, and
`NotificationService` still use the un-styled `TaskDateFormat.format(_:)`
medium overload, so a user who picks "Long Numeric" sees `2026.05.17` on
cards but `May 17, 2026` everywhere else; (b) changing a board's Reminder
Time does not re-schedule existing reminders, so already-set tasks keep
firing at the old time; (c) repeat reminders schedule a batch of 16
one-shots and have no re-batch trigger besides "user saves the task
again", so a Daily reminder silently goes quiet after 16 days. Several
Low items are quality-of-life: "Untitled" is a non-localized literal in
four sites, new boards land with the "Choose a Title" placeholder until
the user clears it by hand, the widget extension has no
`PrivacyInfo.xcprivacy`, `DEVELOPMENT_TEAM` is still hardcoded in
`project.pbxproj`, the README/VersionHistory `(build 3)` lags the
project's `CURRENT_PROJECT_VERSION = 4`, the `HowToUseSheet` "folder
button" copy disagrees with the `archivebox` SF Symbol, and 21
`Localizable.xcstrings` keys are still missing zh-Hans (down from the
prior audit's 118). Areas reviewed: models, services, view models, all
views (board, board switcher, task detail, search, settings, components),
widget target, project configuration, entitlements, privacy info, and
`Localizable.xcstrings` coverage. Not reviewed: live runtime behavior on
device, on-device notification delivery, Instruments traces, asset
catalog contents, asset preview names, the `TestData/testdata.json`
payload.

---

## 2. Issue list

### N1. `settings.dateFormat` is ignored by `TaskDetailView`, `SearchView`, and `NotificationService`

- **Severity:** Medium
- **Related files:** `Task/Views/Task/TaskDetailView.swift:253-254,263`,
  `Task/Views/Search/SearchView.swift:75`,
  `Task/Services/NotificationService.swift:131,134`,
  `Task/Utils/DateFormatters.swift:14-20,49-58`,
  `Task/Components/DateRow.swift:11,28`
- **Description:** `DateRow` and `DueDateRow` pass
  `style: settings.dateFormat` into `TaskDateFormat.format(_:style:)`, so
  board cards honor the user's chosen Date Format. But three other date
  surfaces use the bare `TaskDateFormat.format(_:)` / `formatRange(_:_:)`
  overloads, which always read the `medium` formatter (`May 17, 2026`):
  - `TaskDetailView.workingDateDisplay` (line 253-254) renders working
    dates in the editor.
  - `TaskDetailView`'s `dueDateRow` (line 263) renders due dates in the
    editor.
  - `SearchView.taskRow` (line 75) renders the due date column in search
    results.
  - `NotificationService.dateSummary` (line 131,134) composes the body
    text of every fired notification.

  So a user who picks "Short Numeric" / "Long Numeric" / "Long Text" in
  Settings → Date Format sees the chosen format on board cards, but
  reverts to medium (`May 17, 2026`) inside the editor, in the search
  list, and on notifications.
- **Why it matters:** Explicit user preference silently ignored on every
  surface except the board card. Easy to notice when switching styles to
  see the difference. Also a `LessonsLearned` violation: the
  "TaskDateFormat is the one place dates flow through" idea relies on
  callers passing the style.
- **Suggested fix:**
  - Update the three editor / search callsites to pass
    `settings.dateFormat`.
  - For nonisolated `NotificationService`, mirror the
    `TaskDateFormat.locale` pattern: expose a top-level
    `TaskDateFormatStyle` variable (or a `currentDateStyle` on
    `TaskDateFormat`) that `SettingsViewModel.dateFormat.didSet` updates,
    so the service can render notifications in the user-chosen style
    without touching a `@MainActor` view model.
- **Risks / dependencies:** None. The styled formatters are already
  cached per style; the bare `format(_:)` overload can stay for
  emergencies but should be removed once all callsites pass a style.

### N2. Changing a board's Reminder Time does not re-schedule existing reminders

- **Severity:** Medium
- **Related files:**
  `Task/Views/Settings/AppearanceView.swift:461-467`
  (`ReminderTimePickerSheet.applyAndDismiss`),
  `Task/Services/NotificationService.swift:21-78`,
  `Task/Models/Board.swift:17`
- **Description:** `ReminderTimePickerSheet.applyAndDismiss` writes
  `board.reminderMinutesOfDay` and saves the context. But existing
  scheduled `UNCalendarNotificationTrigger`s for that board's tasks were
  built from the old `reminderMinutesOfDay` value at scheduling time
  (`NotificationService.schedule` line 27-31). Without a re-schedule
  pass, those triggers stay anchored to the old hour/minute, so changing
  the board from 9:00 to 10:00 leaves every already-set reminder firing
  at 9:00.
- **Why it matters:** The user's mental model is "I changed the Reminder
  Time for this board, so my reminders will fire at the new time."
  Reality is "new reminders fire at 10:00; everything that was already
  scheduled is still at 9:00." Silent inconsistency that only surfaces
  when the next reminder actually fires.
- **Suggested fix:** After saving the new value, walk
  `board.tasks?.filter(\.hasReminder)` and call
  `NotificationService.schedule(for: task)` for each (which cancels and
  re-schedules with the new time). For boards with many tasks this could
  be expensive — yielding via `Task.yield()` per 50 schedules mirrors the
  reset/import pattern.
- **Risks / dependencies:** Need to verify that
  `schedule(for:)` is safe to call without an active
  `UNUserNotificationCenter` authorization check at the moment of
  rescheduling (it already silently no-ops if the trigger date is past).
  The watch must not iterate past `repeatBatchSize × tasks` — see N3.

### N3. Repeat reminders silently stop after 16 occurrences

- **Severity:** Medium
- **Related files:**
  `Task/Services/NotificationService.swift:19,40-52`,
  `Task/Models/RepeatRule.swift:21-30`,
  `Task/Views/Task/TaskDetailView.swift:585-590`
- **Description:** When a task has `repeatRule != .none`,
  `NotificationService.schedule(for:)` batches `repeatBatchSize = 16`
  one-shot `UNCalendarNotificationTrigger`s by advancing the rule. The
  comment (line 36-39) notes "Subsequent occurrences are re-scheduled
  the next time the task is saved." If the user never re-opens the task,
  after the 16th occurrence the reminder simply stops — no UI signal,
  no further notifications, no hint that the alarm "wore off." For a
  Daily reminder, this is 16 days; for Weekly, 16 weeks. The card's
  `arrow.clockwise` icon and the editor's "Repeat: Daily" pill both
  still claim the task repeats forever.
- **Why it matters:** Class of silent-failure — exactly the kind a task
  app must not have. A Daily reminder used as a habit anchor degrades
  into silence after two weeks.
- **Suggested fix:** Two complementary moves:
  - (a) On app launch / scene-active (`RootView.task`), walk all tasks
    with `hasReminder && repeatRule != .none` whose last pending
    notification (or last fired date) is within `repeatBatchSize / 2`
    occurrences of running out, and re-schedule them.
  - (b) Document the batch behavior in `LessonsLearned.md` so the next
    contributor doesn't increase `repeatBatchSize` to 64 without
    realizing iOS caps total pending notifications at 64 per app
    (4 daily-repeat tasks would consume the entire budget).
- **Risks / dependencies:** Plumbing `UNUserNotificationCenter.getPendingNotificationRequests`
  is async; refresh should be a fire-and-forget background task so it
  doesn't slow launch.

### N4. Drag rollback watchdog may fire mid-drag if the user lingers on one target

- **Severity:** Low (`Needs verification` on device)
- **Related files:** `Task/Views/Board/BoardView.swift:104-189`
- **Description:** `armDragWatchdog` schedules a 5-second
  `Task.sleep` and only re-arms when `placeTask(commit: false)` is
  called again. `placeTask(commit: false)` is invoked from
  `TaskRowDropDelegate.dropEntered`. Per Apple's drag-and-drop
  documentation, `dropEntered` fires **once** when the drag enters a
  target; `dropUpdated` is the one that fires continuously while
  hovering. The comment at line 155-158 claims "SwiftUI fires
  `dropEntered` continuously while the user moves over a target" — that
  appears to be incorrect. If the user lingers on a single card for
  more than 5 seconds, the watchdog elapses → `rollbackDragIfNeeded`
  reverts every speculative move → preDragState is cleared. When the
  user finally drops, `performDrop` calls
  `applyTaskMove(_, commit: true)` and the move re-applies, so no data
  is lost — but the user sees the card snap back to its original
  column mid-drag and then snap to the destination only on release.
- **Why it matters:** A surprising visual hiccup during slow drags
  (reading a card name before choosing a column, dragging while paused
  by a notification, etc.). The behavior is data-safe but the animation
  looks broken.
- **Suggested fix:** Re-arm the watchdog from `dropUpdated` rather than
  only from `dropEntered`. Cheaper alternative: have the delegate write
  to a shared `@State lastDragTick = Date()` on each `dropUpdated`, and
  let the watchdog re-check against that timestamp instead of trusting
  its own elapsed time.
- **Risks / dependencies:** Cannot reproduce or refute the behavior
  without on-device testing. Marked `Needs verification`. The fix
  itself is one extra line in each `dropUpdated`.

### N5. "Untitled" placeholder is a non-localized String literal in four sites

- **Severity:** Low
- **Related files:** `Task/Views/Board/BoardSwitcherView.swift:124`,
  `Task/Views/Board/TaskCardView.swift:9`,
  `Task/Views/Search/SearchView.swift:62`,
  `Task/Services/UpcomingSnapshotBuilder.swift:31`
- **Description:** Each of these uses the pattern
  `Text(value.isEmpty ? "Untitled" : value)`. The ternary produces a
  `String`, which `Text(_: String)` does NOT auto-localize (only the
  `Text(_: LocalizedStringKey)` overload does — and the compiler picks
  `String` when the expression's type is `String`). The widget snapshot
  case (line 31) is worse: the literal is encoded into the App Group
  JSON and rendered as-is by the widget, with no chance of
  localization at all. Chinese users see "Untitled" in all four
  places instead of "无标题" / similar.
- **Why it matters:** Chinese builds are 91.5% translated overall; this
  is one of the visible regressions.
- **Suggested fix:** Use
  `Text(value.isEmpty ? String(localized: "Untitled") : value)` in the
  three view-layer sites. In the snapshot builder, prefer storing `""`
  and letting `UpcomingTasksWidgetView` render its own localized
  fallback (the widget runs in its own process and gets the user's
  language preference via the system locale anyway).
- **Risks / dependencies:** `Localizable.xcstrings` already has the key
  in zh-Hans. The widget side requires a small `if title.isEmpty`
  branch in `taskRow`.

### N6. New boards land with the placeholder "Choose a Title" / "Choose a Subtitle" instead of empty editable fields

- **Severity:** Low
- **Related files:**
  `Task/Views/Board/BoardSwitcherView.swift:181-188`,
  `Task/Views/Board/ProjectHeaderView.swift:30-43,61-74`
- **Description:** `addBoard` calls
  `SwiftDataManager.createBoard(title: String(localized: "Choose a Title"),
  subtitle: String(localized: "Choose a Subtitle"), …)`, which writes
  those exact strings into `board.title` / `board.subtitle`. The board
  switcher dismisses, the active board changes, and
  `ProjectHeaderView.onAppear` mirrors them into `draftTitle` /
  `draftSubtitle`. The user then has to manually clear the literal
  "Choose a Title" before typing — and on Chinese builds, clear "选择标题".
  The widget snapshot is also rewritten with the placeholder title, so
  the new board appears in the widget edit picker as "Choose a Title"
  until the user edits it.
- **Why it matters:** Friction on a common first-use path. Worse on
  Chinese where the placeholder is wider and harder to clear by tap.
- **Suggested fix:** Two options:
  - (a) Create the board with empty `title` / `subtitle` and rely on
    `TextField(prompt:)` to show the hint without persisting it. The
    header TextFields already pass placeholder text — extending them
    to use `prompt:` keeps the underlying string empty.
  - (b) On board create, autofocus the title field and select all
    placeholder text so the first keystroke replaces it. Requires a
    state hop after `dismiss()`.
- **Risks / dependencies:** Option (a) is cleaner but requires a
  re-check of every site that reads `board.title` / `board.subtitle`
  (e.g., `BoardSwitcherView.boardRowContent:124`,
  `UpcomingSnapshotBuilder.swift:39`) to handle empty strings.

### N7. `HowToUseSheet` "Boards" step 1 still says "folder button"; bottom nav uses `archivebox`

- **Severity:** Low (carryover from prior archive's N16)
- **Related files:**
  `Task/Views/Settings/AboutSheets.swift:110`,
  `Task/Components/BottomNavBar.swift:48,89`,
  `README.md:26`
- **Description:** `BottomNavBar` uses
  `Image(systemName: "archivebox")`. The README's Highlights section
  describes it as "the archive button in the bottom bar." The
  HowToUseSheet's first Boards step still reads "Tap the folder button
  in the bottom bar to open the board switcher." Three different names
  for one icon. Each of the other How-to steps that reference the
  board switcher (e.g., "Tap Add in the switcher") are correct;
  only step 1 of Boards keeps the legacy "folder" copy.
- **Why it matters:** First-time users follow the breadcrumb and look
  for a folder SF Symbol that doesn't exist.
- **Suggested fix:** Replace "folder button" with "archive button" (to
  match README) or "archivebox icon" (most precise) in
  `HowToUseSheet`'s Boards section.
- **Risks / dependencies:** Pure copy change. Also flows through
  `Localizable.xcstrings` if the steps key gets a new English value.

### N8. "More +N" chip still reads as "remaining total", but the number is the next chunk size

- **Severity:** Low (carryover from prior archive's note)
- **Related files:** `Task/Views/Board/ColumnView.swift:161-184`
- **Description:** `moreButton(hidden:)` renders `+\(min(pageSize, hidden))`
  where `pageSize = 10`. So a 47-task column shows "More +10" three
  times in a row, then "More +7" on the fourth tap. The label reads as
  "10 more to see" but actually means "tapping adds 10 more." Users
  often expect the number to shrink as they expand the column.
- **Why it matters:** Mild discoverability issue. Mostly affects
  test-data scale (~125 tasks/board); typical real users won't notice.
- **Suggested fix:** Render "More +10 of 37 left" or "More (10 of 37)"
  to make the next-chunk semantic explicit. Or drop the `+` and write
  "Show 10 more · 37 left".
- **Risks / dependencies:** None. Copy + a small math change.

### N9. 21 `Localizable.xcstrings` keys still missing zh-Hans

- **Severity:** Low (significant improvement from 118 missing)
- **Related files:** `Task/Localizable.xcstrings`
- **Description:** `python3 json.load` reports 248 total keys; 227
  (91.5%) are `state: "translated"` in zh-Hans, 21 are not. Notable
  visible-to-user gaps:
  - Delete-mode bottom buttons: "Delete a Board", "Delete a Status",
    "Delete a Tag", "Delete Status"
  - Notes Preview picker: "1 Line", "2 Lines", "3 Lines", "Off",
    "Hidden"
  - Date Format picker descriptors: "Short Numeric", "Long Numeric",
    "Short Text", "Long Text", "May 17", "May 17, 2026"
  - Date Filter descriptors: "Matches due dates",
    "Matches working days and ranges", "Filter tasks by this date",
    "Show all tasks"
  - TagPickerSheet empty state: "Tap Add to create your first tag."
- **Why it matters:** The user-picked language is honored everywhere
  except these 21 surfaces. Chinese builds therefore mix English into
  the destructive-action buttons and most picker descriptors.
- **Suggested fix:** Add the missing zh-Hans translations directly in
  the catalog (Xcode's String Catalog editor surfaces these as
  `New/Stale`). Spot-check the four key copy rewrites from prior
  audits (Reset confirmation, HowToUseSheet steps, orphan messages,
  How to Use → Defaults) for whether their English values changed
  enough to require a re-translation.
- **Risks / dependencies:** None for the translation. Future copy
  changes should remain `String(localized:)` so the catalog keeps
  auto-extracting.

### N10. `PrivacyInfo.xcprivacy` is present on the Task target but missing on the widget extension

- **Severity:** Low
- **Related files:** `Task/PrivacyInfo.xcprivacy` (exists),
  `TaskWidgetExtension/` (no privacy manifest),
  `TaskWidgetExtension/WidgetSnapshot.swift:62-76`
- **Description:** The widget extension calls
  `UserDefaults(suiteName: "group.com.ijustin.task")` in
  `WidgetSharedDefaults.read` / `readBoardList`. Apple's privacy
  manifest guidance requires each binary (app + each extension) that
  uses one of the declared API categories to ship its own
  `PrivacyInfo.xcprivacy`. The Task app declares
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`; the
  widget extension uses the same API but has no manifest. App Store
  Connect's automated check has flagged similar setups during
  submission.
- **Why it matters:** Potential App Store submission rejection or
  warning during binary upload. Cosmetic until the next App Store
  push.
- **Suggested fix:** Add `TaskWidgetExtension/PrivacyInfo.xcprivacy`
  mirroring the app's manifest:
  ```xml
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
  </array>
  ```
  Synchronized folders pick it up automatically; no pbxproj edit
  needed.
- **Risks / dependencies:** None.

### N11. `DEVELOPMENT_TEAM = U6KN3BQL72` hardcoded across all four target configs

- **Severity:** Low (carryover from prior archive's N7)
- **Related files:**
  `task.xcodeproj/project.pbxproj:451,488,523,552`
- **Description:** Every Debug and Release configuration for the Task
  and TaskWidgetExtension targets hardcodes the development team
  string. Tests targets don't, but the app/widget pair does. A
  contributor cloning the repo has to either edit the pbxproj or
  override the team in Xcode's signing UI before an Archive succeeds.
- **Why it matters:** Friction for collaborators and open-source
  evaluators (README explicitly says "source-available" for personal
  non-commercial evaluation).
- **Suggested fix:** Move signing into a `.xcconfig` file
  (`Config/Signing.xcconfig`) and reference it from
  `XCConfigurationList`. Each contributor keeps their own (gitignored)
  config locally.
- **Risks / dependencies:** Touches build settings; should be tested
  with a clean Archive before checking in.

### N12. README and VersionHistory say "0.4.6 (build 3)" but `CURRENT_PROJECT_VERSION = 4`

- **Severity:** Low
- **Related files:** `README.md:9`, `VersionHistory.md:3`,
  `task.xcodeproj/project.pbxproj:450,487,522,551,602`
- **Description:** README's banner reads
  `Current app version: **0.4.6 (build 3)**`. VersionHistory's most
  recent entry is `## 0.4.6 (build 3) — 2026-05-22`. Both targets in
  the pbxproj have `CURRENT_PROJECT_VERSION = 4` and
  `MARKETING_VERSION = 0.4.6`. Recent commits include `51f9601 Bump
  app version to 0.4.6` and `29d1d5a Polish Task app board and
  settings UI` — so a build 4 was prepared after the build 3 docs
  were written.
- **Why it matters:** Minor docs drift. The app shows
  `AppInfo.versionAndBuild = "0.4.6 (4)"` in Settings → About →
  Version, which contradicts the README.
- **Suggested fix:** Either bump README and VersionHistory to build 4
  (and add a one-line "build 4 — polish" entry under 0.4.6), or rev
  `CURRENT_PROJECT_VERSION` back to `3` if the build was bumped
  prematurely. The commit log suggests the bump was intentional, so
  the docs are stale.
- **Risks / dependencies:** None.

### N13. `primaryReminderDate` fires on `workingEnd` when only a working range is set

- **Severity:** Low
- **Related files:** `Task/Models/TaskItem.swift:67-72`,
  `Task/Views/Task/TaskDetailView.swift:53-61`
- **Description:** When `workingStart != nil` and `dueDate == nil`,
  `primaryReminderDate` returns `dueDate ?? workingEnd ?? workingStart`
  = `workingEnd ?? workingStart`. For a working range like May 10 →
  May 12 with no due date and reminder on, the notification fires on
  May 12 (the end of the range), not May 10 (the start). The
  editor's `reminderAnchor` puts the alarm badge on the Working row,
  which displays the entire range "May 10 → May 12" — the user can't
  tell from the badge which day will fire.
- **Why it matters:** Subtle expectation gap. The user set "Working
  May 10 → May 12, remind me" — most users probably think "remind me
  when this starts" (May 10), but the app fires at the end. The
  archive comment ("falls back to the obvious choice") suggests this
  was a deliberate choice, but it isn't documented for users.
- **Suggested fix:** Pick a side and document it:
  - (a) Change `primaryReminderDate` to fall back to `workingStart`
    rather than `workingEnd` when only working is set. Matches "remind
    me when this starts."
  - (b) Keep `workingEnd` and add a one-liner to the Reminder Time
    section of `HowToUseSheet`: "For working ranges, the reminder
    fires on the last day of the range."
  - (c) Add a per-task "Remind at start / Remind at end" toggle when
    the working date is a range.
- **Risks / dependencies:** Option (a) is the smallest change but
  also retroactively shifts when existing range-only reminders fire
  for users on this build.

### N14. Three reorder `DropDelegate` types are nearly identical across `BoardSwitcherView`, `StatusPickerSheet`, and `TagPickerSheet`

- **Severity:** Low
- **Related files:**
  `Task/Views/Board/BoardSwitcherView.swift:207-252`
  (`BoardReorderDropDelegate`),
  `Task/Views/Task/StatusPickerSheet.swift:264-305`
  (`StatusPickerReorderDropDelegate`),
  `Task/Views/Task/TagPickerSheet.swift:256-301`
  (`TagPickerReorderDropDelegate`)
- **Description:** Each is ~50 lines with the same shape: `dropUpdated`
  returns `.move`; `dropEntered` calls `applyMove(draggedID:)`;
  `performDrop` calls `applyMove`, saves the context, clears the
  `draggingID` binding, and arms a 0.5 s `dragSessionEnded` debounce;
  `applyMove` looks up source + target indices, mutates the ordered
  array via `withAnimation`, and renumbers `sortIndex`. The only
  differences are the model type (`Board` / `BoardGroup` / `TaskTag`)
  and the source list (`boards` / `board.orderedGroups` /
  `board.orderedTags`).
- **Why it matters:** Code that has to change in lockstep three times
  is the change-friction cost. The N12 fix in the prior archive
  (snapshot save bookkeeping) only resolved one of three sites for
  this same reason.
- **Suggested fix:** A small generic helper:
  ```swift
  struct ReorderDropDelegate<Item: Identifiable>: DropDelegate {
      let target: Item
      let ordered: () -> [Item]
      let setSortIndex: (Item, Int) -> Void
      let onSave: () -> Void
      @Binding var draggingID: Item.ID?
      @Binding var dragSessionEnded: Bool
      // ...generic dropUpdated/Entered/performDrop bodies
  }
  ```
  Each callsite passes its `board.orderedGroups` / `board.orderedTags`
  / `boards` closure and the `\.sortIndex` setter. Three files lose
  ~120 lines combined.
- **Risks / dependencies:** None functional. Generic constraints
  (`Item: Identifiable` with `ID == UUID`) need a quick check against
  every callsite.

---

## 3. Code quality findings

- **Duplicated code:**
  - Drag-reorder DropDelegate triplet (see N14):
    `BoardSwitcherView.swift:207-252`,
    `StatusPickerSheet.swift:264-305`,
    `TagPickerSheet.swift:256-301`.
  - Snapshot save bookkeeping (`try? context.save()` +
    `UpcomingSnapshotBuilder.writeSnapshot(from: context)`) appears in
    13 sites:
    `BoardView.swift:140-141`,
    `BoardSwitcherView.swift:199-200`,
    `ProjectHeaderView.swift:79-80,123-125`,
    `GroupMenuSheet.swift:111-112,139-140`,
    `StatusPickerSheet.swift:259-260`,
    `TaskDetailView.swift:533+540,596-597`,
    `DataImportExport.swift:274+281,498+518`,
    `SwiftDataManager.swift:120-121`,
    `RootView.swift:104`. Most callers also call
    `WidgetCenter.shared.reloadAllTimelines()` indirectly via the
    builder, which is good — but the duo would still benefit from a
    single `BoardWriter.save(_:context:)` helper that touches
    `updatedAt`, saves, writes the snapshot, and is the single place
    to add a future invariant (e.g., debounce widget reloads to once
    per 0.5 s under heavy import churn).
  - "Untitled" non-localized placeholder appears in four sites
    (`BoardSwitcherView.swift:124`, `TaskCardView.swift:9`,
    `SearchView.swift:62`,
    `UpcomingSnapshotBuilder.swift:31`). See N5.
  - Group deletion fallback-reassignment logic appears in two sites
    (`GroupMenuSheet.swift:115-141`,
    `StatusPickerSheet.swift:237-261`) with identical
    `var base = (fallback.orderedTasks.last?.sortIndex ?? -1)` snapshot
    trick. Both sites correctly handle the inverse-relationship
    read-staleness bug per the comments. Could share a helper but the
    duplication is small (~15 lines each).

- **Unused or outdated files / symbols:**
  - No fully orphaned files this pass. The orphan trio from prior
    audits (`ManageGroupsView`, `ManageTagsView`,
    `DefaultStatusPickerSheet`) is fully wired or removed.
  - `Issues-gg.md` and `Issues-cx.md` exist at the repo root (27.1 KB
    + 16.9 KB). They are not referenced by any internal markdown
    link, README, or skill. Possibly review artifacts from external
    tools. Out of scope for this skill — flagging only so a future
    pass can decide whether to archive them under `docs/` like the
    main Issues archive.

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` (~600 lines now) — title +
    six property rows + two date sub-sheets + repeat picker + delete
    confirmation + load/save/delete + advance + candidateFireDate +
    reminderAnchor. Splitting `workingDateSheet`, `dueDateSheet`, and
    `propertyRow` into their own files would halve this.
  - `Task/Views/Settings/AppearanceView.swift` (~470 lines) — eight
    `*PickerSheet` wrappers + the shared `FlatSettingsChoicePicker` +
    the entire `ReminderTimePickerSheet` (lines 245-468). The keypad
    picker is unrelated to the appearance flat-pickers and would read
    cleaner in its own file
    (`Task/Views/Settings/ReminderTimePickerSheet.swift`).
  - `Task/Services/DataImportExport.swift:312-482`
    (`mergeBoard(_:into:plan:)`) is 170 lines. Extracting
    `mergeGroups`, `mergeTags`, `mergeTasks` would mirror the natural
    shape and keep the notification-plan accounting in one focused
    place.

- **Naming inconsistencies:**
  - `ColumnView.groupDragPrefix = "group:"` (line 24) and a literal
    `"group:"` at line 252-253. The constant and the literal can
    diverge; either drop the constant or use it at the parse site.
  - `Board.cardSortFieldRaw` is `String` while
    `Board.defaultGroupID` is `String?` — both are "stringly-typed
    SwiftData fields, exposed as type-safe accessors." Documented in
    the `defaultGroupUUID` doc comment (line 50-52); the cardSortField
    pair doesn't have the same comment. Minor.
  - "Untitled" literal vs `String(localized: "Untitled")` (see N5).

- **Structural improvements:**
  - Funnel every snapshot write + widget reload through a single
    `BoardWriter.save(board:context:)` actor / helper. Today every
    save site has to remember to call
    `UpcomingSnapshotBuilder.writeSnapshot` and most do; a few
    (`TagPickerSheet.addTag` / `deleteTag`) skip it because tag
    data doesn't surface in the widget — codifying the rule and
    centralizing the choice would make it explicit instead of
    implicit.
  - Cross-target color palette is duplicated between `ColorKey`
    (Task) and `WidgetColorKey` (TaskWidgetExtension), both
    re-declaring the same RGB tuples. Same cross-target drift risk as
    the snapshot Codable structs. Could live in a small shared
    source-only file the synchronized folder pulls into both targets
    via `membershipExceptions` inversions.

---

## 4. Functional issues

- **Boards** — Default seed (Personal / Study / Work) covered by
  `testSeedCreatesThreeDefaultBoards`. Add board through the switcher
  works and immediately becomes active. Board reorder via long-press
  drag works. Delete board via expanded sheet → delete-mode → tap row
  → confirmation works; cascade-deletes tasks and cancels their
  notifications. Active-board fallback on delete uses the next
  remaining board.
- **Board / columns / cards** — Pagination, `.id()` re-render on sort
  change, and pull-to-refresh all work. Card drag-reorder correctly
  no-ops in non-Manual sort modes for same-column moves and routes
  cross-column drops to end-of-list. Watchdog rollback (5 s) catches
  releases outside any drop target — but may misfire mid-drag (N4).
- **Drag and drop** — Cross-column drops save once via
  `placeTask(commit: true)`. Within-column live drag yields smoothly.
  Drop proposal `.move` everywhere — no green `+` badge.
- **Calendar picker** — Today button jumps + selects correctly. Range
  mode after both endpoints are set: tapping start swaps end into
  start and clears end; tapping a third date starts a fresh
  selection. Documented in `LessonsLearned`.
- **Search** — Cross-board search works; active board surfaces first.
  `groupedResults` recomputes every body update — fine at current
  expected scale, but a debounce would help at thousands of tasks.
- **Default Status picker** — Reachable via the flag icon in
  `ProjectHeaderView`; writes `board.defaultGroupUUID`; the new-task
  sheet uses `board.defaultGroup` which falls back to
  `orderedGroups.first` when the stored ID is missing.
- **Manage Groups / Manage Tags screens** — Done via in-flow surfaces
  (`GroupMenuSheet`, `StatusPickerSheet`, `TagPickerSheet`). The
  delete-mode toggle is consistent across all three.
- **Import / Export / Reset** — Round-trips correctly for self-
  exported data. Orphan counts and inserted/updated counts surface
  in the success alert with plural rules. Reset shows a
  `ProgressOverlay` and yields every 50 tasks during the cancellation
  loop. Reset returns `false` and the UI shows a `resetFailure` alert
  if the destructive save fails.
- **Notifications** — Past-date guard skips occurrences before now.
  Authorization-denied state surfaces a banner inside `TaskDetailView`
  when `hasReminder` is enabled (line 288-299). Reminder is
  auto-disabled when the user removes all dates
  (`disableReminderIfNoDates`). Repeat is batched as 16 one-shots —
  silent failure after 16 occurrences (N3). Time-of-day is read from
  the per-board `reminderMinutesOfDay` at schedule time — changing
  the board setting does NOT re-schedule existing reminders (N2).
- **Widget snapshot** — `UpcomingSnapshotBuilder.writeSnapshot` calls
  `WidgetCenter.shared.reloadAllTimelines()` at the end of every
  rebuild. Snapshot date encoding is `.iso8601` on both sides. Board
  list is rewritten on every snapshot write so the configuration
  intent's `BoardEntityQuery` sees current boards. The widget's
  `primaryDate` (min of all three dates) diverges intentionally from
  `TaskItem.primaryReminderDate` to surface tasks that "start before
  they're due" — the divergence is documented in
  `UpcomingSnapshotBuilder.swift:16-21`.
- **Localization** — Catalog covers 91.5% of keys in zh-Hans, up from
  42% in the prior audit. 21 visible-to-user keys still untranslated
  (N9). `TaskDateFormat.locale` is updated from
  `SettingsViewModel.language.didSet` so dates render in the chosen
  locale.

---

## 5. UI/UX issues

- **N1 (dateFormat ignored in editor/search/notifications)** —
  user-visible inconsistency between board cards and every other
  date surface.
- **N2 (Reminder Time change doesn't reschedule)** — silent failure.
- **N3 (Repeat reminders silently stop)** — silent failure.
- **N4 (Drag watchdog may rollback mid-drag)** — animation flicker;
  needs device verification.
- **N5 ("Untitled" non-localized)** — Chinese build regression.
- **N6 (New board placeholder titles persist)** — first-use friction.
- **N7 (HowToUseSheet says "folder")** — docs vs code drift.
- **N8 ("More +N" chip ambiguity)** — minor copy.
- **N13 (Reminder fires on workingEnd for ranges)** — subtle
  expectation gap.
- **Drag preview shapes** — all card surfaces use
  `.contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8 or 10
  or 22, style: .continuous))`. No green `+` badge anywhere. Matches
  LessonsLearned guidance.
- **iOS 26 fallback parity** — `BottomNavBar` forks via
  `#available(iOS 26.0, *)`; the iOS 18-25 fallback uses
  `.thinMaterial` + `secondarySystemBackground` circles with the same
  control set. No regressions vs the Glass variant in the code; not
  verified on-device.
- **MarkdownNotesEditor** — Markdown preview is clean; tapping any
  rendered line jumps back into edit mode. The blank-line handler
  (line 75-79) renders a clear 8 pt area whose `onTapGesture`
  triggers `beginEditing()` — works but is a narrow hit target.
- **ProjectHeaderView icon buttons** — Sort / Date Filter / Default
  Status icons are visually identical except for system symbol. Only
  the Date Filter icon tints when active (`tint: isDateFilterActive
  ? .accentColor : .primary`). Sort icon stays neutral even when sort
  is not Manual; Default Status icon stays neutral even when a
  non-first default is set. Asymmetric affordance.

---

## 6. Data and persistence issues

- **Cascade deletes** — `Board.groups` / `tags` / `tasks` all set
  `deleteRule: .cascade`. `BoardGroup.tasks` uses `.nullify` — so
  deleting a group through SwiftData alone would orphan its tasks.
  Live delete paths (`GroupMenuSheet.deleteAndDismiss`,
  `StatusPickerSheet.deleteGroup`) reassign tasks to the fallback
  group before deleting; the cascade-from-Board path (in `resetAll`
  and `BoardSwitcherView.deleteBoard`) deletes everything anyway, so
  no orphan. Good.
- **CloudKit-readiness invariants** hold: every `@Model` property in
  `Board`, `BoardGroup`, `TaskTag`, `TaskItem` has a default value,
  no `@Attribute(.unique)`, optional inverse relationships.
- **In-memory fallback signal** — `RootView` surfaces the alert
  exactly once per launch via `surfaceInMemoryWarningIfNeeded`. The
  `inMemoryFallbackKey` is flipped to `false` on the next successful
  container open. `resetAll` also calls `purgePersistentStoreFiles`
  when the app is running in the in-memory fallback so the corrupt
  on-disk SQLite gets cleared before re-seeding.
- **Snapshot encoding** — both write paths use `.iso8601`; widget
  decoder matches. `WidgetUpcomingEntry.primaryDate` deliberately
  diverges from `TaskItem.primaryReminderDate` — documented but
  surprising (see N13's neighbor).
- **`writeBoardList` uses default `JSONEncoder()`** —
  `SharedDefaultsService.swift:53-58` doesn't set
  `dateEncodingStrategy`. `BoardListEntry` currently has no `Date`
  fields so this is benign; if a `Date` is ever added, remember to
  mirror the `.iso8601` rule.
- **Export ordering** — `BoardExportEntry.tasks` are written in
  whatever order `(board.tasks ?? [])` returns; round-trip still
  works because `sortIndex` is persisted, but the exports are not
  byte-identical across runs. Same as prior audit.
- **N2 (Reminder Time change doesn't reschedule)** — the change is
  saved to the model immediately, but pending
  `UNCalendarNotificationTrigger`s are not refreshed.
- **N3 (Repeat batch exhaustion)** — pending notifications quietly
  run out after 16 occurrences.

---

## 7. Configuration and platform issues

- **N10 (Missing widget privacy manifest)** — see issue list.
- **N11 (Hardcoded DEVELOPMENT_TEAM)** — see issue list.
- **N12 (README build number lags pbxproj)** — see issue list.
- **iOS deployment target 18.0** in all four targets — matches README
  requirements. `#available(iOS 26.0, *)` paths in `BottomNavBar` are
  the only forks.
- **App Group `group.com.ijustin.task`** is correctly configured on
  both `Task.entitlements` and `TaskWidgetExtension.entitlements`.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  remains excluded via `PBXFileSystemSynchronizedBuildFileExceptionSet`
  (lines 56-62 in pbxproj). Task target uses
  `GENERATE_INFOPLIST_FILE = YES` with the `INFOPLIST_KEY_*` settings —
  no checked-in `Task/Info.plist` needed.
- **`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet
  Midnight Neutral Light"`** (line 444) matches
  `AppIconOption.alternateName` (Classic / Rose / Violet / Midnight /
  Neutral / Light, where Classic is the primary). Not verified
  against the asset catalog contents.
- **`PrivacyInfo.xcprivacy`** on the Task target declares
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
  Widget extension still lacks one — see N10.
- **Portrait-only orientation** in
  `INFOPLIST_KEY_UISupportedInterfaceOrientations =
  UIInterfaceOrientationPortrait` for both Task release & debug
  configurations. Matches the UI.
- **`LSApplicationCategoryType = public.app-category.productivity`**
  set — App Store category-ready.
- **`TARGETED_DEVICE_FAMILY = 1`** (iPhone only). Matches design.
- **`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`** — set on both
  targets; new strings auto-extract on build.
- **`Swift 5.0`** — the project still pins `SWIFT_VERSION = 5.0`. iOS
  18 / Xcode 16 default to Swift 6 by default; staying on 5 keeps the
  actor-isolation churn out of the way. Worth a deliberate decision
  before any 0.5.x feature work.

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - `NotificationService.schedule` for repeat rules: assert
    `repeatBatchSize` triggers are added, identifiers follow
    `task.id@offset` shape, and cancel removes all of them.
  - `disableReminderIfNoDates` in `TaskDetailView`: the @State flip
    when the user clears the last date with reminder on. Hard to
    unit-test without a SwiftUI host; can be re-shaped into a static
    pure helper for testability.
  - `DataImportExport.importData` round-trip integrity at the v2 wire
    format and the v1 legacy fall-back (`LegacySingleBoardPayload`).
  - `DataImportExport.mergeBoard` orphan paths:
    - missing groupID → fallback to first group, increment
      `orphanTasks`.
    - missing tagID in `tagIDs` → drop the tag, increment
      `orphanTagRefs`.
    - name-conflict for groups/tags inside the same board (case
      differences, duplicate names).
  - `DataImportExport.resetAll`: cancellation runs for every prior
    task before the seed runs; `task.activeBoardID` is cleared.
  - Group delete reassignment (`GroupMenuSheet.deleteAndDismiss`,
    `StatusPickerSheet.deleteGroup`): five tasks in group A,
    delete A, assert all five land at the tail of the first remaining
    group with monotonically increasing `sortIndex`.
  - Cross-board task isolation: a task added to board A must not
    surface in board B's `SearchView.groupedResults` or column
    rendering.
  - Drag-reorder math: same-column reorder when in non-Manual sort
    should leave `sortIndex` unchanged (per the `applyTaskMove`
    branches). Cross-column drop in non-Manual sort should land at
    end-of-column.
  - `primaryReminderDate` semantics across:
    - both `workingStart` and `dueDate` set (min of the two).
    - only `workingStart` set.
    - only `dueDate` set.
    - `workingStart` + `workingEnd` (range) only — see N13.
  - `migrateLegacyBoardDefaultsIfNeeded` one-shot: preload
    UserDefaults legacy keys, run `ensureSeed`, assert the first
    board picks up the migrated values and
    `task.boardDefaultsMigrated` is set; confirm idempotent on second
    run.
  - Snapshot encode → widget decode round-trip with all optional
    fields populated (`boardID`, `boardEmoji`, `boardTitle`).

- **Suggested tests:**
  - `testRepeatBatchSchedulesSixteenTriggers()` — set a `.daily`
    repeat with reminder on; assert pending request count is 16
    after a `Task.sleep(100ms)` to let `add(_:withCompletionHandler:)`
    flush. Requires test-host entitlements.
  - `testDateFormatStyleAppliesAcrossFormatRange()` — assert that
    `TaskDateFormat.formatRange(start, end, style: .longNumeric)`
    yields `2026.05.17 → 2026.05.20`, not the medium pattern.
  - `testImportV1LegacyPayloadWrapsIntoSingleEntry()` — feed
    `LegacySingleBoardPayload`-shaped JSON, assert `payload.boards.count
    == 1` and fields match.
  - `testImportOrphanTaskLandsInFirstGroup()` — import a task with a
    non-existent `groupID`, assert task is placed in
    `board.orderedGroups.first` and `outcome.orphanTasks == 1`.
  - `testImportOrphanTagRefDropsButPreservesTask()` — import a task
    with an unknown UUID in `tagIDs`, assert `outcome.orphanTagRefs ==
    1` and the task is created with the remaining valid tags.
  - `testGroupDeleteReassignsTasksAndRenumbers()` — five tasks in
    group A; delete A via `StatusPickerSheet.deleteGroup`; assert all
    five live in the first remaining group with `sortIndex` 0..4
    appended after the fallback's existing tail.
  - `testReorderDoesNothingWhenTargetIsSelf()` —
    `ReorderDropDelegate.dropEntered` early-returns when draggedID ==
    target.id; assert no `sortIndex` changes.
  - `testWatchdogRollbackOnlyReplacesChangedTasks()` — pre-record
    `preDragState`, mutate two tasks' groupID/sortIndex via
    `placeTask(commit: false)`, fire `rollbackDragIfNeeded()`,
    assert only those two tasks are touched.
  - `testNotificationPastDateSkips()` — set a past dueDate, call
    `NotificationService.schedule`, assert no pending request for
    `task.id.uuidString`. Test-host entitlements required.
  - `testReminderTimeChangeReschedulesPendingNotifications()` —
    create task with reminder, schedule, change
    `board.reminderMinutesOfDay`, assert the pending trigger's
    `dateComponents` reflect the new hour/minute. Test-host
    entitlements required.

- **Manual / device-only:**
  - Verify widget refreshes promptly after task edits in a real
    widget install across all three families (small / medium /
    large).
  - Confirm `setAlternateIconName` actually swaps app icons on iOS 18
    and iOS 26.
  - VoiceOver pass over `BottomNavBar`, `BoardSwitcherView`
    (delete-mode rows), `BoardView`, `TaskDetailView`,
    `MarkdownNotesEditor`.
  - Reproduce N4: start a drag, hover one card for >5 seconds without
    moving, watch for a card snap-back to original column mid-drag.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — Plumb `settings.dateFormat` through `TaskDetailView`,
    `SearchView`, and `NotificationService`. One-day change; removes
    a visible drift across every date surface.
  - **N2** — On `board.reminderMinutesOfDay` change, walk pending
    reminders and re-schedule. Removes a silent inconsistency users
    would only catch after a missed reminder.
  - **N3** — Refresh repeat-reminder batches on app launch /
    scene-active so a Daily reminder doesn't go quiet after 16 days.
    Same silent-failure class as N2; both are user-trust issues.
- **Fix next:**
  - **N4** — Re-arm the drag rollback watchdog from `dropUpdated`,
    not just `dropEntered`. Verify on device first.
  - **N5** — Wrap the four "Untitled" sites in
    `String(localized: "Untitled")` (and store "" in the snapshot so
    the widget can render its own localized placeholder).
  - **N6** — New board create should start with empty title/
    subtitle and rely on `TextField(prompt:)` for the hint instead
    of pre-filling "Choose a Title".
  - **N7** — Update HowToUseSheet's "folder button" copy to match
    the archivebox icon.
  - **N9** — Translate the remaining 21 zh-Hans keys before the
    next Chinese-targeted release.
  - **N13** — Pick a side on workingEnd vs workingStart for range-
    only reminders, then document it in `HowToUseSheet`'s Reminders
    section.
- **Optional cleanup:**
  - **N8** — Rephrase the "More +N" chip ("Show 10 more · 37 left").
  - **N10** — Add `TaskWidgetExtension/PrivacyInfo.xcprivacy`.
  - **N11** — Move `DEVELOPMENT_TEAM` into `.xcconfig`.
  - **N12** — Reconcile README's "build 3" with pbxproj's
    `CURRENT_PROJECT_VERSION = 4` (likely by bumping README +
    VersionHistory).
  - **N14** — Consolidate the three reorder DropDelegates into a
    generic helper.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- `docs/IssuesArchive-01.md` and `docs/IssuesArchive-02.md`
  cross-referenced against current code for every prior issue. N1–N5,
  N7–N8, N10–N15, N17–N19 from archive 02 are resolved or replaced by
  better implementations; N6 is partially resolved (DateFormatter
  locale honors the user's setting now); N9 is partially resolved
  (toolbar conventions are still mixed but acceptable); N10 (zh-Hans
  coverage) is significantly improved (42% → 91.5%, 21 keys
  remaining); N13 (defaultGroupID type) is structurally addressed via
  `defaultGroupUUID` accessor; N16 (folder vs archivebox naming)
  partially survives in HowToUseSheet copy.
- All Swift sources under `Task/`:
  - Models (`Board`, `BoardGroup`, `TaskTag`, `TaskItem`, `ColorKey`,
    `RepeatRule`).
  - Services (`SwiftDataManager`, `NotificationService`,
    `SharedDefaultsService`, `UpcomingSnapshotBuilder`,
    `DataImportExport`).
  - Utils (`AppInfo`, `DateFormatters`).
  - ViewModels (`SettingsViewModel`).
  - Views: `RootView`, board (`BoardView`, `BoardSwitcherView`,
    `ColumnView`, `GroupMenuSheet`, `ProjectHeaderView`, `TaskCardView`,
    `BoardIconPickerSheet`), task (`TaskDetailView`,
    `MarkdownNotesEditor`, `RepeatPickerSheet`, `StatusPickerSheet`,
    `TagPickerSheet`), search (`SearchView`), settings (`SettingsView`,
    `AppearanceView`, `CardOrderPickerSheet`, `DefaultStatusPickerSheet`,
    `IconPickerSheet`, `ManualControlSheet`, `AboutSheets`).
  - Components (`BottomNavBar`, `CalendarPicker`, `CardBackground`,
    `ColorSwatchPicker`, `ConfirmationSheet`, `DateRow`, `FlowLayout`,
    `GridTile`, `GroupHeaderPill`, `ProgressOverlay`, `SettingsCard`,
    `StringMoveDropDelegate`, `TagChip`).
- All Swift sources under `TaskWidgetExtension/` (`TaskWidgetBundle`,
  `UpcomingTasksProvider`, `UpcomingTasksWidget`, `WidgetSnapshot`,
  `BoardConfigurationIntent`).
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`, `TaskWidgetExtension/Info.plist`.
- `task.xcodeproj/project.pbxproj` — build settings, synchronized
  folder exceptions, code signing, marketing/current version,
  INFOPLIST keys, bundle IDs, asset catalog config.
- `Task/Localizable.xcstrings` — programmatic count of total keys
  (248) vs zh-Hans `state: "translated"` (227, 91.5%), with the 21
  missing keys enumerated.
- `TaskTests/TaskTests.swift`.
- Grep queries (all via `rtk proxy grep`):
  - `DefaultStatusPickerSheet`, `ManageGroupsView`, `ManageTagsView`,
    `ReminderTimePickerSheet` (to confirm orphan files of the prior
    audit are removed or rewired).
  - `UpcomingSnapshotBuilder.writeSnapshot`,
    `WidgetCenter.reloadAllTimelines` (snapshot/widget reload trace).
  - `TODO|FIXME|XXX` (no matches).
  - `repeats: true|repeats: false` (verify N14-archive resolution).
  - `Untitled|String(localized` (N5 trace + localization audit).
  - `TooMuchToDo|Work Harder` (verify N17-archive resolution).
  - `Add\"|Done\"|Cancel\"|Save\"` (toolbar audit).
  - `settings.dateFormat|TaskDateFormat.format` (N1 trace).
  - `primaryReminderDate|workingEnd ?? workingStart`,
    `primaryDate` (N13 + widget divergence).

## Not checked (worth a follow-up)

- Actual runtime behavior on iOS 18.x vs iOS 26 devices / simulators
  (Liquid Glass parity, alternate icon transitions, drag previews,
  the ProgressOverlay animation while a `@MainActor` reset runs to
  completion, widget reload cadence under heavy edit churn).
- On-device notification delivery, authorization-denied paths, and
  notification body composition in different locales — particularly
  the N1 fix and any regression in `NotificationService.dateSummary`.
- Instruments / memory profile for a board with thousands of tasks;
  `SearchView` at scale; `UpcomingSnapshotBuilder` cost when called
  rapid-fire during a large import.
- Widget rendering under each `WidgetFamily` on a real device, and
  the configuration intent picker after a board rename / icon change.
- Asset catalog contents: that
  `Rose/Violet/Midnight/Neutral/Light` and the corresponding
  `*Preview` previews actually exist;
  `INCLUDE_ALL_APPICON_ASSETS = YES` is set but the catalog itself is
  not part of this audit. `IconPickerSheet` references
  `option.previewAssetName` directly — a missing asset would render
  a blank tile.
- The 21 remaining zh-Hans translations themselves — only their
  English keys were enumerated, not proposed Chinese values.
- Accessibility audit (Dynamic Type extremes, VoiceOver labels, hit
  targets, drag-and-drop accessibility).
- N3 / N4 device behavior: the watchdog mid-drag rollback claim and
  the repeat-reminder exhaustion claim both want a real device run
  to confirm.
- `Issues-cx.md` and `Issues-gg.md` at the repo root — present but
  not referenced anywhere; not part of this audit's input.
- `TestData/testdata.json` integrity — 211 KB JSON file, not
  diff-walked here.
