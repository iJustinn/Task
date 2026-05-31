import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import Task

@MainActor
final class TaskTests: XCTestCase {
    func makeContainer() throws -> ModelContainer {
        let schema = Schema([Board.self, BoardGroup.self, TaskTag.self, TaskItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testSeedCreatesThreeDefaultBoards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        SwiftDataManager.ensureSeed(context: context)
        let boards = try context.fetch(FetchDescriptor<Board>()).sorted { $0.sortIndex < $1.sortIndex }
        XCTAssertEqual(boards.map(\.title), ["Personal", "Study", "Work"])
        XCTAssertEqual(boards.map(\.iconEmoji), ["🏃", "🎓", "💼"])
        for board in boards {
            XCTAssertEqual(board.orderedGroups.map(\.name), ["Waiting", "Doing", "Pending", "Done", "Archive"])
            XCTAssertTrue(board.orderedTags.isEmpty, "Default boards should have no preset tags")
        }
    }

    func testTaskWorkingRangeDetection() throws {
        let task = TaskItem(title: "Range", notes: "")
        let start = Date()
        task.workingStart = start
        task.workingEnd = Calendar.current.date(byAdding: .day, value: 2, to: start)
        XCTAssertTrue(task.workingIsRange)
        task.workingEnd = nil
        XCTAssertFalse(task.workingIsRange)
    }

    func testBiweeklyRepeatAdvancesByTwoWeeks() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let advanced = RepeatRule.biweekly.advance(start, calendar: calendar)
        let expected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 6)))

        XCTAssertEqual(advanced, expected)
    }

    func testQuarterlyAndAnnuallyRepeatAdvanceByExpectedIntervals() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))

        XCTAssertEqual(
            RepeatRule.quarterly.advance(start, calendar: calendar),
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 23)))
        )
        XCTAssertEqual(
            RepeatRule.annually.advance(start, calendar: calendar),
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 5, day: 23)))
        )
    }

    func testRepeatingReminderSchedulesOnlyCurrentCardDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let chosenDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))
        let expectedFireDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 8, minute: 15)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let board = Board(title: "Board")
        board.reminderMinutesOfDay = 8 * 60 + 15
        let task = TaskItem(title: "Repeat reminder", notes: "")
        task.board = board
        task.dueDate = chosenDay
        task.hasReminder = true
        task.repeatRule = .daily

        let dates = NotificationService.fireDates(for: task, now: now, calendar: calendar)

        XCTAssertEqual(dates, [expectedFireDate])
    }

    func testSpecificTimeOnDateOverridesBoardReminderTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        // A due date that carries a specific time-of-day (14:30) — the editor bakes the
        // chosen "Specific Time" into the stored date.
        let specificDateTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 14, minute: 30)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let board = Board(title: "Board")
        board.reminderMinutesOfDay = 9 * 60 // The board fallback (09:00) must NOT win here.
        let task = TaskItem(title: "Timed reminder", notes: "")
        task.board = board
        task.dueDate = specificDateTime
        task.hasReminder = true

        let dates = NotificationService.fireDates(for: task, now: now, calendar: calendar)

        XCTAssertEqual(dates, [specificDateTime])
    }

    func testEarlierExplicitTimeWinsOverLaterBoardFallback() throws {
        let calendar = Calendar(identifier: .gregorian)
        // Same day: working has an explicit 08:00; due has no specific time (midnight)
        // and would resolve to the board's 09:00. The reminder must fire at the earlier
        // resolved time (08:00), not pick the midnight due date and then bump it to 09:00.
        let workingAt8 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 8, minute: 0)))
        let dueMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let board = Board(title: "Board")
        board.reminderMinutesOfDay = 9 * 60
        let task = TaskItem(title: "Mixed times", notes: "")
        task.board = board
        task.workingStart = workingAt8
        task.dueDate = dueMidnight
        task.hasReminder = true

        let dates = NotificationService.fireDates(for: task, now: now, calendar: calendar)

        XCTAssertEqual(dates, [workingAt8])
    }

    func testFormatWithTimeAppendsOnlyForSpecificTimes() throws {
        let calendar = Calendar(identifier: .gregorian)
        let midnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))
        let timed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 14, minute: 30)))

        // Midnight (no Specific Time) renders identically to the plain date formatter,
        // so existing timeless cards/rows are unchanged. (Locale-independent.)
        XCTAssertEqual(TaskDateFormat.formatWithTime(midnight, style: .shortText),
                       TaskDateFormat.format(midnight, style: .shortText))

        // A specific time keeps the bare date as a prefix and appends the time.
        let timedString = TaskDateFormat.formatWithTime(timed, style: .shortText)
        XCTAssertTrue(timedString.hasPrefix(TaskDateFormat.format(timed, style: .shortText)))
        XCTAssertGreaterThan(timedString.count, TaskDateFormat.format(timed, style: .shortText).count)

        // In a range only the start carries the time; the end stays day-level.
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 28)))
        let range = TaskDateFormat.formatRangeWithTime(timed, end, style: .shortText)
        XCTAssertTrue(range.contains("→"))
        XCTAssertTrue(range.hasPrefix(timedString))
        XCTAssertTrue(range.hasSuffix(TaskDateFormat.format(end, style: .shortText)))
    }

    func testRepeatingReminderDoesNotAutoAdvancePastCardDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let chosenDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let task = TaskItem(title: "Stale repeat reminder", notes: "")
        task.dueDate = chosenDay
        task.hasReminder = true
        task.repeatRule = .weekly

        let dates = NotificationService.fireDates(for: task, now: now, calendar: calendar)
        let rootSource = try loadProjectFile(relativePath: "Task/Views/RootView.swift")

        XCTAssertEqual(task.dueDate, chosenDay)
        XCTAssertEqual(dates, [])
        XCTAssertFalse(rootSource.contains("advanceRepeatingReminderIfNeeded"))
    }

    func testCompletingCheckboxTaskClearsReminderWithoutRestoringItOnUncheck() {
        let task = TaskItem(title: "Checked reminder", notes: "")
        task.showsCheckbox = true
        task.hasReminder = true

        let canceledReminder = task.toggleCheckboxChecked()

        XCTAssertTrue(canceledReminder)
        XCTAssertTrue(task.isChecked)
        XCTAssertFalse(task.hasReminder)

        let canceledReminderOnUncheck = task.toggleCheckboxChecked()

        XCTAssertFalse(canceledReminderOnUncheck)
        XCTAssertFalse(task.isChecked)
        XCTAssertFalse(task.hasReminder)
    }

    func testCheckedCheckboxReminderPolicyClearsReminderForEditorSaves() {
        let task = TaskItem(title: "Editor checked reminder", notes: "")
        task.showsCheckbox = true
        task.isChecked = true
        task.hasReminder = true

        let canceledReminder = task.clearReminderIfCheckedCheckbox()

        XCTAssertTrue(canceledReminder)
        XCTAssertFalse(task.hasReminder)
    }

    func testTaskDuplicateCopiesEditableFieldsAndRelationships() throws {
        let board = Board(title: "Board", subtitle: "Test")
        board.iconEmoji = "✅"
        let group = BoardGroup(name: "Doing", colorKey: .blue, sortIndex: 0)
        let tag = TaskTag(name: "Health", colorKey: .green, sortIndex: 0)
        let calendar = Calendar(identifier: .gregorian)
        let workingStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let workingEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 24)))
        let dueDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25)))

        let task = TaskItem(title: "Sign up", notes: "[] research", sortIndex: 4)
        task.board = board
        task.group = group
        task.tags = [tag]
        task.workingStart = workingStart
        task.workingEnd = workingEnd
        task.dueDate = dueDate
        task.hasReminder = true
        task.repeatRule = .weekly
        task.showsCheckbox = true
        task.isChecked = true

        let duplicate = task.duplicated(sortIndex: 5)

        XCTAssertNotEqual(duplicate.id, task.id)
        XCTAssertEqual(duplicate.title, task.title)
        XCTAssertEqual(duplicate.notes, task.notes)
        XCTAssertEqual(duplicate.sortIndex, 5)
        XCTAssertEqual(duplicate.board?.id, board.id)
        XCTAssertEqual(duplicate.group?.id, group.id)
        XCTAssertEqual(duplicate.tags?.map { $0.id }, [tag.id])
        XCTAssertEqual(duplicate.workingStart, workingStart)
        XCTAssertEqual(duplicate.workingEnd, workingEnd)
        XCTAssertEqual(duplicate.dueDate, dueDate)
        XCTAssertTrue(duplicate.hasReminder)
        XCTAssertEqual(duplicate.repeatRule, RepeatRule.weekly)
        XCTAssertTrue(duplicate.showsCheckbox)
        XCTAssertTrue(duplicate.isChecked)
    }

    func testTaskExportDecodesCheckboxFieldsAndDefaultsLegacyPayloadsToOff() throws {
        let id = UUID()
        let createdAt = "2026-05-23T00:00:00Z"
        let updatedAt = "2026-05-23T01:00:00Z"

        let legacyJSON = """
        {
          "id": "\(id.uuidString)",
          "title": "Legacy",
          "notes": "",
          "hasReminder": false,
          "sortIndex": 0,
          "createdAt": "\(createdAt)",
          "updatedAt": "\(updatedAt)",
          "tagIDs": []
        }
        """
        let legacy = try DataImportExport.makeDecoder().decode(TaskExport.self, from: Data(legacyJSON.utf8))
        XCTAssertFalse(legacy.showsCheckbox)
        XCTAssertFalse(legacy.isChecked)

        let currentJSON = """
        {
          "id": "\(id.uuidString)",
          "title": "Current",
          "notes": "",
          "hasReminder": false,
          "showsCheckbox": true,
          "isChecked": true,
          "sortIndex": 0,
          "createdAt": "\(createdAt)",
          "updatedAt": "\(updatedAt)",
          "tagIDs": []
        }
        """
        let current = try DataImportExport.makeDecoder().decode(TaskExport.self, from: Data(currentJSON.utf8))
        XCTAssertTrue(current.showsCheckbox)
        XCTAssertTrue(current.isChecked)
    }

    func testBoardGroupCardDisplayLimitDefaultsToFiveAndSupportsAllChoices() {
        let group = BoardGroup(name: "Waiting")

        XCTAssertEqual(group.cardDisplayLimit, .five)
        XCTAssertEqual(group.cardDisplayLimit.initialVisibleCount(totalCount: 23), 5)

        let expectations: [(CardDisplayLimit, String, Int?)] = [
            (.five, "5", 5),
            (.ten, "10", 10),
            (.fifteen, "15", 15),
            (.twenty, "20", 20),
            (.all, "all", nil)
        ]

        for (limit, rawValue, count) in expectations {
            group.cardDisplayLimit = limit

            XCTAssertEqual(group.cardDisplayLimitRaw, rawValue)
            XCTAssertEqual(group.cardDisplayLimit.count, count)
        }

        group.cardDisplayLimit = .all
        XCTAssertEqual(group.cardDisplayLimit.initialVisibleCount(totalCount: 23), 23)
    }

    func testCalendarPickerClearSingleDateSelection() {
        var selected: Date? = Date()
        let binding = Binding<Date?>(
            get: { selected },
            set: { selected = $0 }
        )

        CalendarPickerSelection.clear(selectedDate: binding)

        XCTAssertNil(selected)
    }

    func testCalendarPickerClearRangeSelection() {
        var start: Date? = Date()
        var end: Date? = Calendar.current.date(byAdding: .day, value: 2, to: start!)
        let startBinding = Binding<Date?>(
            get: { start },
            set: { start = $0 }
        )
        let endBinding = Binding<Date?>(
            get: { end },
            set: { end = $0 }
        )

        CalendarPickerSelection.clear(rangeStart: startBinding, rangeEnd: endBinding)

        XCTAssertNil(start)
        XCTAssertNil(end)
    }

    func testGroupExportDefaultsLegacyCardDisplayLimitToFive() throws {
        let id = UUID()
        let legacyJSON = """
        {
          "id": "\(id.uuidString)",
          "name": "Waiting",
          "colorKey": "blue",
          "sortIndex": 0,
          "createdAt": "2026-05-23T00:00:00Z"
        }
        """

        let group = try DataImportExport.makeDecoder().decode(GroupExport.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(group.cardDisplayLimitRaw, CardDisplayLimit.five.rawValue)
    }

    func testImportSuccessMessageDoesNotExposeInflectionMarkup() {
        let outcome = ImportResult(success: true, boardCount: 3, taskCount: 375)

        let message = ImportResultMessageFormatter.successMessage(for: outcome)

        XCTAssertEqual(message, "Imported 3 boards and 375 tasks.")
        XCTAssertFalse(message.contains("^["))
        XCTAssertFalse(message.contains("inflect: true"))
    }

    func testImportSuccessMessageFormatsSingularAndWarnings() {
        let outcome = ImportResult(
            success: true,
            boardCount: 1,
            taskCount: 1,
            orphanTasks: 1,
            orphanTagRefs: 2
        )

        let message = ImportResultMessageFormatter.successMessage(for: outcome)

        XCTAssertEqual(
            message,
            """
            Imported 1 board and 1 task.

            1 task moved to the first group because its original group wasn't in the file.
            2 tag references couldn't be resolved and were dropped.
            """
        )
        XCTAssertFalse(message.contains("^["))
        XCTAssertFalse(message.contains("inflect: true"))
    }

    func testStorageSummaryCountsAppDataModelsAndExportBytes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let board = Board(title: "Storage")
        let group = BoardGroup(name: "Waiting", colorKey: .blue, sortIndex: 0)
        let tag = TaskTag(name: "Work", colorKey: .purple, sortIndex: 0)
        let task = TaskItem(title: "Check", notes: "")
        board.groups = [group]
        board.tags = [tag]
        board.tasks = [task]
        group.board = board
        tag.board = board
        task.board = board
        task.group = group
        task.tags = [tag]
        context.insert(board)
        try context.save()

        let summary = DataImportExport.storageSummary(context: context)

        XCTAssertEqual(summary.itemCount, 4)
        XCTAssertEqual(summary.byteCount, try XCTUnwrap(DataImportExport.exportData(context: context)).count)
    }

    func testStorageSummaryUsesInflectedItemCountCatalogKey() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")

        XCTAssertNotNil(strings["^[%lld item](inflect: true)"])
        XCTAssertNil(strings["items"])
    }

    func testDefaultExportFileNameUsesStableGregorianTimestamp() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 13, minute: 7)))

        XCTAssertEqual(
            DataImportExport.defaultExportFileName(for: date, timeZone: calendar.timeZone),
            "task-export-2026-05-26-1307"
        )
    }

    func testImportedInvalidReminderTimeKeepsDefaultBoardReminderTime() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let boardID = UUID()
        let createdAt = Date()
        let payload = MultiBoardExportPayload(
            boards: [
                BoardExportEntry(
                    board: BoardExport(
                        id: boardID,
                        title: "Imported",
                        subtitle: "",
                        iconEmoji: nil,
                        sortIndex: 0,
                        defaultGroupID: nil,
                        cardSortFieldRaw: nil,
                        cardSortDirectionRaw: nil,
                        reminderMinutesOfDay: 24 * 60,
                        createdAt: createdAt,
                        updatedAt: createdAt
                    ),
                    groups: [],
                    tags: [],
                    tasks: []
                )
            ]
        )
        let data = try DataImportExport.makeEncoder().encode(payload)

        let result = await DataImportExport.importData(data, context: context)
        let boards = try context.fetch(FetchDescriptor<Board>())

        XCTAssertTrue(result.success)
        XCTAssertEqual(boards.first?.reminderMinutesOfDay, ReminderDefaults.defaultMinutesOfDay)
    }

    func testDateFormatterRebuildsLocalizedPatternAfterLocaleChanges() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)))
        TaskDateFormat.locale = Locale(identifier: "en_US")
        _ = TaskDateFormat.format(date, style: .shortText)

        TaskDateFormat.locale = Locale(identifier: "zh_Hans")
        let localized = TaskDateFormat.format(date, style: .shortText)
        TaskDateFormat.locale = .autoupdatingCurrent

        XCTAssertTrue(localized.contains("月"))
        XCTAssertTrue(localized.contains("31"))
        XCTAssertFalse(localized.contains(" "))
    }

    func testBoardDefaultGroupToggleSetsAndMovesDefaultWhenDisabled() {
        let board = Board(title: "Board")
        let waiting = BoardGroup(name: "Waiting", colorKey: .blue, sortIndex: 0)
        let doing = BoardGroup(name: "Doing", colorKey: .red, sortIndex: 1)
        board.groups = [waiting, doing]

        board.setDefaultGroup(doing, enabled: true)

        XCTAssertEqual(board.defaultGroupUUID, doing.id)

        board.setDefaultGroup(waiting, enabled: false)

        XCTAssertEqual(board.defaultGroupUUID, doing.id)

        board.setDefaultGroup(doing, enabled: false)

        XCTAssertEqual(board.defaultGroupUUID, waiting.id)
        XCTAssertEqual(board.defaultGroup?.id, waiting.id)
    }

    func testTaskDateFilterCanTargetWorkingRangeOrDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let may10 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 10)))
        let may11 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 11)))
        let may12 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 12)))
        let may13 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)))
        let may9 = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: may10))

        let task = TaskItem(title: "Range and due", notes: "")
        task.workingStart = may10
        task.workingEnd = may12
        task.dueDate = may13

        XCTAssertTrue(task.matchesDateFilter(may10, target: .workingDate, calendar: calendar))
        XCTAssertTrue(task.matchesDateFilter(may11, target: .workingDate, calendar: calendar))
        XCTAssertTrue(task.matchesDateFilter(may12, target: .workingDate, calendar: calendar))
        XCTAssertFalse(task.matchesDateFilter(may13, target: .workingDate, calendar: calendar))
        XCTAssertFalse(task.matchesDateFilter(may9, target: .workingDate, calendar: calendar))

        XCTAssertFalse(task.matchesDateFilter(may12, target: .dueDate, calendar: calendar))
        XCTAssertTrue(task.matchesDateFilter(may13, target: .dueDate, calendar: calendar))
    }

    func testBoardDateSliderWindowUsesWorkingDateBoundsFromTasks() throws {
        let calendar = Calendar(identifier: .gregorian)
        let may10 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 14)))
        let may12 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 9)))
        let june3 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 18)))
        let ignoredDue = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 8)))

        let rangeTask = TaskItem(title: "Range", notes: "")
        rangeTask.workingStart = may12
        rangeTask.workingEnd = may10
        rangeTask.dueDate = ignoredDue

        let laterTask = TaskItem(title: "Later", notes: "")
        laterTask.workingStart = june3

        let dates = BoardDateSliderDayWindow.dates(
            for: [rangeTask, laterTask],
            target: .workingDate,
            fallback: may10,
            calendar: calendar
        )

        XCTAssertEqual(dates.first, calendar.startOfDay(for: may10))
        XCTAssertEqual(dates.last, calendar.startOfDay(for: june3))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: may12)))
        XCTAssertFalse(dates.contains(calendar.startOfDay(for: ignoredDue)))
        XCTAssertTrue(dates.allSatisfy { calendar.isDate($0, equalTo: calendar.startOfDay(for: $0), toGranularity: .second) })
    }

    func testBoardDateSliderWindowUsesDueDateBoundsFromTasks() throws {
        let calendar = Calendar(identifier: .gregorian)
        let ignoredWorking = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 2)))
        let may9 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 9, hour: 22)))
        let june14 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 8)))

        let firstTask = TaskItem(title: "First due", notes: "")
        firstTask.workingStart = ignoredWorking
        firstTask.dueDate = may9

        let lastTask = TaskItem(title: "Last due", notes: "")
        lastTask.dueDate = june14

        let dates = BoardDateSliderDayWindow.dates(
            for: [firstTask, lastTask],
            target: .dueDate,
            fallback: may9,
            calendar: calendar
        )

        XCTAssertEqual(dates.first, calendar.startOfDay(for: may9))
        XCTAssertEqual(dates.last, calendar.startOfDay(for: june14))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: may9)))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: june14)))
        XCTAssertFalse(dates.contains(calendar.startOfDay(for: ignoredWorking)))
    }

    func testBoardDateSliderWindowIncludesFocusDateWhenTasksDoNotUseThatDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let focus = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let later = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3)))

        let task = TaskItem(title: "Later", notes: "")
        task.workingStart = later

        let dates = BoardDateSliderDayWindow.dates(
            for: [task],
            target: .workingDate,
            fallback: focus,
            calendar: calendar
        )

        XCTAssertEqual(dates.first, calendar.startOfDay(for: focus))
        XCTAssertEqual(dates.last, calendar.startOfDay(for: later))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: focus)))
    }

    func testBoardDateSliderWindowCapsDatesToOneYearAroundToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let selectedFocus = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 9)))
        let lowerCap = try XCTUnwrap(calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: today)))
        let upperCap = try XCTUnwrap(calendar.date(byAdding: .year, value: 1, to: calendar.startOfDay(for: today)))
        let beforeCap = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: lowerCap))
        let afterCap = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: upperCap))

        let dates = BoardDateSliderDayWindow.dates(
            for: [
                dueDateTask(beforeCap),
                dueDateTask(lowerCap),
                dueDateTask(upperCap),
                dueDateTask(afterCap)
            ],
            target: .dueDate,
            fallback: selectedFocus,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(dates.first, lowerCap)
        XCTAssertEqual(dates.last, upperCap)
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: today)))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: selectedFocus)))
        XCTAssertFalse(dates.contains(beforeCap))
        XCTAssertFalse(dates.contains(afterCap))
    }

    private func dueDateTask(_ date: Date) -> TaskItem {
        let task = TaskItem(title: "Due", notes: "")
        task.dueDate = date
        return task
    }

    func testUpcomingSnapshotSortPrioritizesStatusOrderBeforeDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let sooner = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))
        let later = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 24)))

        let pendingSooner = SharedDefaultsService.UpcomingSnapshotEntry(
            id: UUID(),
            title: "Pending sooner",
            dueDate: sooner,
            workingStart: nil,
            workingEnd: nil,
            groupName: "Pending",
            groupColorKey: ColorKey.yellow.rawValue,
            groupSortIndex: 2,
            boardID: UUID(),
            boardEmoji: "🏃",
            boardTitle: "Personal"
        )
        let waitingLater = SharedDefaultsService.UpcomingSnapshotEntry(
            id: UUID(),
            title: "Waiting later",
            dueDate: later,
            workingStart: nil,
            workingEnd: nil,
            groupName: "Waiting",
            groupColorKey: ColorKey.blue.rawValue,
            groupSortIndex: 0,
            boardID: UUID(),
            boardEmoji: "🏃",
            boardTitle: "Personal"
        )

        let sorted = UpcomingSnapshotBuilder.sortedEntries([pendingSooner, waitingLater])

        XCTAssertEqual(sorted.map(\.title), ["Waiting later", "Pending sooner"])
    }

    func testWidgetStatusListUsesBoardAndStatusOrder() {
        let personal = Board(title: "Personal")
        personal.iconEmoji = "🏃"
        personal.sortIndex = 1
        let personalDoing = BoardGroup(name: "Doing", colorKey: .red, sortIndex: 1)
        let personalWaiting = BoardGroup(name: "Waiting", colorKey: .blue, sortIndex: 0)
        personal.groups = [personalDoing, personalWaiting]

        let work = Board(title: "Work")
        work.iconEmoji = "💼"
        work.sortIndex = 0
        let workDone = BoardGroup(name: "Done", colorKey: .green, sortIndex: 1)
        let workWaiting = BoardGroup(name: "Waiting", colorKey: .yellow, sortIndex: 0)
        work.groups = [workDone, workWaiting]

        let statuses = UpcomingSnapshotBuilder.statusListEntries(from: [personal, work])

        XCTAssertEqual(statuses.map { "\($0.boardTitle):\($0.name)" }, [
            "Work:Waiting",
            "Work:Done",
            "Personal:Waiting",
            "Personal:Doing"
        ])
        XCTAssertEqual(statuses.map(\.boardID), [work.id, work.id, personal.id, personal.id])
        XCTAssertEqual(statuses.map(\.boardEmoji), ["💼", "💼", "🏃", "🏃"])
        XCTAssertEqual(statuses.map(\.colorKey), [
            ColorKey.yellow.rawValue,
            ColorKey.green.rawValue,
            ColorKey.blue.rawValue,
            ColorKey.red.rawValue
        ])
    }

    func testWidgetBoardListUsesBoardOrder() {
        let personal = Board(title: "Personal")
        personal.iconEmoji = "🏃"
        personal.sortIndex = 1
        let work = Board(title: "Work")
        work.iconEmoji = "💼"
        work.sortIndex = 0

        let boards = UpcomingSnapshotBuilder.boardListEntries(from: [personal, work])

        XCTAssertEqual(boards.map(\.title), ["Work", "Personal"])
        XCTAssertEqual(boards.map(\.iconEmoji), ["💼", "🏃"])
    }

    func testTextSizeSettingsAreShiftedOneSizeUpAndDefaultToMedium() {
        XCTAssertEqual(AppTextSize.small.dynamicType, .large)
        XCTAssertEqual(AppTextSize.medium.dynamicType, .xLarge)
        XCTAssertEqual(AppTextSize.large.dynamicType, .xxLarge)
        XCTAssertEqual(AppTextSize.extraLarge.dynamicType, .xxxLarge)

        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: SettingsViewModel.textSizeKey)
        defaults.removeObject(forKey: SettingsViewModel.textSizeKey)
        defer {
            if let original {
                defaults.set(original, forKey: SettingsViewModel.textSizeKey)
            } else {
                defaults.removeObject(forKey: SettingsViewModel.textSizeKey)
            }
        }

        let settings = SettingsViewModel()
        XCTAssertEqual(settings.textSize, .medium)
    }

    func testNotesPreviewUsesNewStorageKeyAndFallsBackToLegacyKey() {
        let defaults = UserDefaults.standard
        let newKey = "task.notesPreview"
        let legacyKey = "task.notesPreviewEnabled"
        let originalNew = defaults.string(forKey: newKey)
        let originalLegacy = defaults.string(forKey: legacyKey)
        defer {
            if let originalNew {
                defaults.set(originalNew, forKey: newKey)
            } else {
                defaults.removeObject(forKey: newKey)
            }
            if let originalLegacy {
                defaults.set(originalLegacy, forKey: legacyKey)
            } else {
                defaults.removeObject(forKey: legacyKey)
            }
        }

        defaults.set(AppNotesPreview.oneLine.rawValue, forKey: legacyKey)
        defaults.set(AppNotesPreview.threeLines.rawValue, forKey: newKey)
        XCTAssertEqual(SettingsViewModel().notesPreview, .threeLines)

        defaults.removeObject(forKey: newKey)
        XCTAssertEqual(SettingsViewModel().notesPreview, .oneLine)

        let settings = SettingsViewModel()
        settings.notesPreview = .twoLines
        XCTAssertEqual(defaults.string(forKey: newKey), AppNotesPreview.twoLines.rawValue)
        XCTAssertEqual(defaults.string(forKey: legacyKey), AppNotesPreview.oneLine.rawValue)
    }

    func testSearchModeDefaultsToListAndPersistsFilter() {
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: SettingsViewModel.searchModeKey)
        defaults.removeObject(forKey: SettingsViewModel.searchModeKey)
        defer {
            if let original {
                defaults.set(original, forKey: SettingsViewModel.searchModeKey)
            } else {
                defaults.removeObject(forKey: SettingsViewModel.searchModeKey)
            }
        }

        let settings = SettingsViewModel()
        XCTAssertEqual(settings.searchMode, .list)

        settings.searchMode = .filter
        XCTAssertEqual(defaults.string(forKey: SettingsViewModel.searchModeKey), AppSearchMode.filter.rawValue)
        XCTAssertEqual(SettingsViewModel().searchMode, .filter)
    }

    func testTaskSearchQueryMatchesTitleNotesStatusAndTags() {
        let group = BoardGroup(name: "Doing")
        let tag = TaskTag(name: "Errands")
        let task = TaskItem(title: "Buy milk", notes: "Use grocery coupon")
        task.group = group
        task.tags = [tag]

        XCTAssertTrue(task.matchesSearchQuery("milk"))
        XCTAssertTrue(task.matchesSearchQuery("GROCERY"))
        XCTAssertTrue(task.matchesSearchQuery("doing"))
        XCTAssertTrue(task.matchesSearchQuery("errand"))
        XCTAssertTrue(task.matchesSearchQuery("  coupon  "))
        XCTAssertFalse(task.matchesSearchQuery("invoice"))
        XCTAssertFalse(task.matchesSearchQuery("   "))
    }

    func testColorKeyRoundTrip() {
        for key in ColorKey.allCases {
            let raw = key.rawValue
            XCTAssertEqual(ColorKey(rawValue: raw), key)
        }
    }

    func testStringCatalogHasTranslatedZhHansForActiveKeys() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")

        let requiredKeys = [
            "Reminder date/time has already passed — this reminder won't fire. Pick a future date or change Reminder Time in Settings."
        ]

        for key in requiredKeys {
            XCTAssertNotNil(strings[key], "Missing string catalog key: \(key)")
        }

        let missing = strings.compactMap { key, value -> String? in
            if value["extractionState"] as? String == "stale" {
                return nil
            }
            guard let localizations = value["localizations"] as? [String: Any],
                  let zhHans = localizations["zh-Hans"] as? [String: Any],
                  let stringUnit = zhHans["stringUnit"] as? [String: Any],
                  stringUnit["state"] as? String == "translated" else {
                return key
            }
            return nil
        }

        XCTAssertTrue(missing.isEmpty, "Missing zh-Hans translations: \(missing.sorted().joined(separator: ", "))")
    }

    func testAboutSheetCopyIsCatalogedAndCatalogHasNoManualWorkarounds() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")
        let requiredKeys = [
            "Create Tasks",
            "Notes & Checklists",
            "Organize the Board",
            "Tags & Groups",
            "Dates & Reminders",
            "Defaults",
            "Widget",
            "Local-First Data",
            "Network Access",
            "Notifications",
            "Your Control",
            "Tap + in the bottom bar to start a new task and type a title.",
            "Tap the Notes area on a task to type. Markdown is supported — **bold**, *italic*, # heading, and - bullet lines all render once you tap away.",
            "Task does not make any network requests on its own.",
            "Local notifications depend on your device permissions and iOS scheduling; if a reminder is critical, also confirm it with the system Calendar or Reminders app."
        ]

        let missing = requiredKeys.filter { strings[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Missing About catalog keys: \(missing.joined(separator: ", "))")

        let manual = strings.compactMap { key, value -> String? in
            value["extractionState"] as? String == "manual" ? key : nil
        }
        XCTAssertTrue(manual.isEmpty, "Manual catalog entries remain: \(manual.sorted().joined(separator: ", "))")
    }

    func testColumnWidthSettingIsStatusWidthInBoardSection() throws {
        let settingsSource = try loadProjectFile(relativePath: "Task/Views/Settings/SettingsView.swift")
        let pickerSource = try loadProjectFile(relativePath: "Task/Views/Settings/AppearanceView.swift")

        let appearanceStart = try XCTUnwrap(settingsSource.range(of: "private var appearanceSection"))
        let boardStart = try XCTUnwrap(settingsSource.range(of: "private var boardSection"))
        let dataStart = try XCTUnwrap(settingsSource.range(of: "private var dataSection"))
        let appearanceSection = settingsSource[appearanceStart.lowerBound..<boardStart.lowerBound]
        let boardSection = settingsSource[boardStart.lowerBound..<dataStart.lowerBound]

        XCTAssertFalse(appearanceSection.contains("title: \"Group Width\""))
        XCTAssertFalse(appearanceSection.contains("title: \"Status Width\""))
        XCTAssertTrue(boardSection.contains("title: \"Status Width\""))
        XCTAssertFalse(boardSection.contains("title: \"Group Width\""))
        XCTAssertTrue(pickerSource.contains("FlatSettingsChoicePicker(title: \"Status Width\""))
        XCTAssertFalse(pickerSource.contains("FlatSettingsChoicePicker(title: \"Group Width\""))
    }

    func testSearchModeSettingIsInBoardSection() throws {
        let settingsSource = try loadProjectFile(relativePath: "Task/Views/Settings/SettingsView.swift")
        let pickerSource = try loadProjectFile(relativePath: "Task/Views/Settings/AppearanceView.swift")

        let appearanceStart = try XCTUnwrap(settingsSource.range(of: "private var appearanceSection"))
        let boardStart = try XCTUnwrap(settingsSource.range(of: "private var boardSection"))
        let dataStart = try XCTUnwrap(settingsSource.range(of: "private var dataSection"))
        let appearanceSection = settingsSource[appearanceStart.lowerBound..<boardStart.lowerBound]
        let boardSection = settingsSource[boardStart.lowerBound..<dataStart.lowerBound]

        XCTAssertFalse(appearanceSection.contains("title: \"Search Mode\""))
        XCTAssertTrue(boardSection.contains("title: \"Search Mode\""))
        XCTAssertTrue(pickerSource.contains("FlatSettingsChoicePicker(title: \"Search Mode\""))
    }

    func testStatusWidthCopyIsCataloged() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")
        let requiredKeys = [
            "Status Width",
            "Status Width controls how wide each status column on the board is — Small (180), Medium (200), or Large (220).",
            "Settings > Board to switch Date Filter, Date Format, Notes Preview, Status Width, Search Mode, and Reminder Time.",
            "Settings > Appearance to switch Theme, Language, Text Size, App Accent, and App Icon."
        ]

        let missing = requiredKeys.filter { strings[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Missing Status Width catalog keys: \(missing.joined(separator: ", "))")
    }

    func testSearchModeCopyIsCataloged() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")
        let requiredKeys = [
            "Search Mode",
            "List",
            "Filter",
            "Show global results",
            "Filter current board",
            "Search Mode chooses whether search opens a global results list or filters cards on the current board."
        ]

        let missing = requiredKeys.filter { strings[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Missing Search Mode catalog keys: \(missing.joined(separator: ", "))")
    }

    func testSearchResultRowsUseTaskCardMetadataStyling() throws {
        let source = try loadProjectFile(relativePath: "Task/Views/Search/SearchView.swift")

        XCTAssertTrue(source.contains("TagChip(name: group.name"))
        XCTAssertTrue(source.contains("SearchMetadataSeparatorDot()"))
        XCTAssertTrue(source.contains("if task.group != nil, !(task.tags?.isEmpty ?? true)"))
        XCTAssertTrue(source.contains("TagChip(name: tag.name"))
        XCTAssertTrue(source.contains("DateRow("))
        XCTAssertTrue(source.contains("DueDateRow("))
        XCTAssertTrue(source.contains("TaskCardFooterIcons(task: task, showsDivider: false)"))
        XCTAssertFalse(source.contains("Circle().fill(group.colorKey.dot)"))
    }

    func testSearchMetadataSeparatorDotCentersOnCompactChipLabelHeight() throws {
        let source = try loadProjectFile(relativePath: "Task/Views/Search/SearchView.swift")
        let separatorStart = try XCTUnwrap(source.range(of: "private struct SearchMetadataSeparatorDot"))
        let separatorSource = source[separatorStart.lowerBound...]

        XCTAssertTrue(separatorSource.contains(".font(.caption2.weight(.medium))"))
        XCTAssertTrue(separatorSource.contains(".padding(.vertical, 2)"))
        XCTAssertTrue(separatorSource.contains(".overlay(alignment: .center)"))
        XCTAssertFalse(separatorSource.contains("@ScaledMetric(relativeTo: .caption2) private var height"))
    }

    func testTaskCardsAndSearchRowsShareFooterIcons() throws {
        let source = try loadProjectFile(relativePath: "Task/Views/Board/TaskCardView.swift")

        XCTAssertTrue(source.contains("struct TaskCardFooterIcons"))
        XCTAssertTrue(source.contains("TaskCardFooterIcons(task: task)"))
        XCTAssertTrue(source.contains("accessibilityLabel(Text(\"Repeats\"))"))
        XCTAssertTrue(source.contains("accessibilityLabel(Text(\"Has notes\"))"))
        XCTAssertTrue(source.contains("accessibilityLabel(Text(\"Has reminder\"))"))
    }

    func testTaskCardFooterAccessibilityLabelsAreCataloged() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")
        let requiredKeys = ["Repeats", "Has notes", "Has reminder"]
        let missing = requiredKeys.filter { strings[$0] == nil }

        XCTAssertTrue(missing.isEmpty, "Missing card footer accessibility labels: \(missing.joined(separator: ", "))")
    }

    func testReleaseDocsMatchCurrentBuildAndMentionRecentVisibleChanges() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let readme = try String(contentsOf: projectRoot.appending(path: "README.md"), encoding: .utf8)
        let history = try String(contentsOf: projectRoot.appending(path: "VersionHistory.md"), encoding: .utf8)
        let project = try String(contentsOf: projectRoot.appending(path: "task.xcodeproj/project.pbxproj"), encoding: .utf8)

        XCTAssertTrue(readme.contains("0.5.0 (build 2)"))
        XCTAssertTrue(history.contains("## 0.5.0 (build 2)"))
        XCTAssertTrue(history.contains("Repeating task dates no longer auto-advance"))
        XCTAssertTrue(history.contains("Notes now preserve the current line's indentation"))
        XCTAssertFalse(project.contains("CURRENT_PROJECT_VERSION = 1;"))
        XCTAssertTrue(project.contains("CURRENT_PROJECT_VERSION = 2;"))
    }

    func testTaskEditorVisibleLabelsAreActiveInStringCatalog() throws {
        let strings = try loadStringCatalog(relativePath: "Task/Localizable.xcstrings")
        let visibleLabels = [
            "Status",
            "Tags",
            "Working",
            "Due Date",
            "Reminder",
            "Checkbox",
            "Repeat",
            "End Date",
            "Specific Time"
        ]

        let missingOrStale = visibleLabels.filter { key in
            guard let entry = strings[key] else { return true }
            return entry["extractionState"] as? String == "stale"
        }

        XCTAssertTrue(missingOrStale.isEmpty, "Visible task editor labels missing or stale: \(missingOrStale.joined(separator: ", "))")
    }

    func testWidgetStringCatalogIncludesMetadataKeys() throws {
        let strings = try loadStringCatalog(relativePath: "TaskWidgetExtension/Localizable.xcstrings")
        let requiredKeys = [
            "%lld upcoming",
            "Background",
            "Black",
            "Board",
            "Choose Board and Status",
            "Default",
            "No upcoming",
            "No upcoming tasks",
            "Pick which board and status the widget shows. Leave empty to see tasks from every board or status.",
            "See tasks with a working or due date in the next seven days. Choose a board or show all of them.",
            "Status",
            "Untitled",
            "Upcoming",
            "Upcoming Tasks",
            "White"
        ]

        let missing = requiredKeys.filter { strings[$0] == nil }

        XCTAssertTrue(missing.isEmpty, "Missing widget catalog keys: \(missing.joined(separator: ", "))")
    }

    func testCardNotesPreviewParsesTaskLinesAsTypedRows() {
        let lines = cardNotesPreviewLines(
            from: """
            - [ ] research
            - [x] payment
            plain note
            """,
            limit: 3
        )

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].kind, .task(checked: false))
        XCTAssertEqual(String(lines[0].text.characters), "research")
        XCTAssertEqual(lines[1].kind, .task(checked: true))
        XCTAssertEqual(String(lines[1].text.characters), "payment")
        XCTAssertEqual(lines[2].kind, .text)
        XCTAssertEqual(String(lines[2].text.characters), "plain note")
    }

    func testCardNotesPreviewPreservesLeadingIndentationForTextAndTasks() {
        let lines = cardNotesPreviewLines(from: "  plain note\n\t[] indented task", limit: 2)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].indentation, "  ")
        XCTAssertEqual(cardNoteIndentWidth(for: lines[0].indentation), 10)
        XCTAssertEqual(lines[0].kind, .text)
        XCTAssertEqual(String(lines[0].text.characters), "plain note")

        XCTAssertEqual(lines[1].indentation, "\t")
        XCTAssertEqual(cardNoteIndentWidth(for: lines[1].indentation), 24)
        XCTAssertEqual(lines[1].kind, .task(checked: false))
        XCTAssertEqual(String(lines[1].text.characters), "indented task")
    }

    func testNotesEditorParsesBareBracketTaskLines() {
        let lines = parseNoteLines(
            """
            [] research
            [x] payment
            """
        )

        XCTAssertEqual(lines.count, 2)

        guard case let .task(firstChecked, firstContent) = lines[0].kind else {
            XCTFail("Expected first line to parse as an unchecked task")
            return
        }
        XCTAssertFalse(firstChecked)
        XCTAssertEqual(firstContent, "research")

        guard case let .task(secondChecked, secondContent) = lines[1].kind else {
            XCTFail("Expected second line to parse as a checked task")
            return
        }
        XCTAssertTrue(secondChecked)
        XCTAssertEqual(secondContent, "payment")
    }

    func testNotesEditorPreservesLeadingIndentationForTextAndTasks() {
        let lines = parseNoteLines("  plain note\n\t[] indented task")

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].indentation, "  ")
        let twoSpaceIndentWidth = noteIndentWidth(for: lines[0].indentation)
        XCTAssertGreaterThan(twoSpaceIndentWidth, 0)

        guard case let .plain(firstContent) = lines[0].kind else {
            XCTFail("Expected first line to parse as plain text")
            return
        }
        XCTAssertEqual(firstContent, "plain note")

        XCTAssertEqual(lines[1].indentation, "\t")
        XCTAssertGreaterThan(noteIndentWidth(for: lines[1].indentation), twoSpaceIndentWidth)

        guard case let .task(isChecked, secondContent) = lines[1].kind else {
            XCTFail("Expected second line to parse as an unchecked task")
            return
        }
        XCTAssertFalse(isChecked)
        XCTAssertEqual(secondContent, "indented task")
    }

    func testNotesEditorTogglesBareBracketTaskMarkers() {
        XCTAssertEqual(toggleTaskMarker(in: "[] research"), "[x] research")
        XCTAssertEqual(toggleTaskMarker(in: "[x] payment"), "[] payment")
        XCTAssertEqual(toggleTaskMarker(in: "  [] indented"), "  [x] indented")
    }

    func testLiveMarkdownEditingStylePreservesMarkersAndStylesMarkdown() throws {
        let raw = """
        # Heading
        [] research
        **bold** and *italic*
        """
        let styled = markdownEditingAttributedText(raw)

        XCTAssertEqual(styled.string, raw)

        let headingFont = try XCTUnwrap(styled.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let bodyFont = try XCTUnwrap(styled.attribute(.font, at: raw.utf16Offset(of: "research"), effectiveRange: nil) as? UIFont)
        XCTAssertGreaterThan(headingFont.pointSize, bodyFont.pointSize)

        let checkboxColor = try XCTUnwrap(styled.attribute(.foregroundColor, at: raw.utf16Offset(of: "[]"), effectiveRange: nil) as? UIColor)
        XCTAssertEqual(checkboxColor, UIColor.secondaryLabel)

        let boldFont = try XCTUnwrap(styled.attribute(.font, at: raw.utf16Offset(of: "bold"), effectiveRange: nil) as? UIFont)
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.traitBold))

        let italicFont = try XCTUnwrap(styled.attribute(.font, at: raw.utf16Offset(of: "italic"), effectiveRange: nil) as? UIFont)
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testLiveMarkdownEditingStyleKeepsBodyFontSizeAcrossLongAndMultilineText() throws {
        let bodyFont = UIFont.systemFont(ofSize: 20)
        let raw = """
        First line
        Second line
        \(String(repeating: "Long text ", count: 20))
        """
        let styled = markdownEditingAttributedText(raw, bodyFont: bodyFont)

        for phrase in ["First", "Second", "Long"] {
            let font = try XCTUnwrap(styled.attribute(.font, at: raw.utf16Offset(of: phrase), effectiveRange: nil) as? UIFont)
            XCTAssertEqual(font.pointSize, bodyFont.pointSize)
        }

        let typingFont = try XCTUnwrap(markdownEditingTypingAttributes(bodyFont: bodyFont)[.font] as? UIFont)
        XCTAssertEqual(typingFont.pointSize, bodyFont.pointSize)
    }

    func testLiveMarkdownEditingSkipsRestylingDuringMarkedTextComposition() {
        XCTAssertFalse(shouldRestyleMarkdownText(hasMarkedText: true))
        XCTAssertTrue(shouldRestyleMarkdownText(hasMarkedText: false))
    }

    func testLiveMarkdownEditingPreservesCurrentLineIndentOnReturn() {
        let textView = MarkdownUITextView()
        textView.text = "Parent\n\t  Indented line"
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)

        textView.insertText("\n")

        XCTAssertEqual(textView.text, "Parent\n\t  Indented line\n\t  ")
        XCTAssertEqual(textView.selectedRange.location, (textView.text as NSString).length)
    }

    func testSwipeToEditMetricsMoveRowsOnlyForHorizontalLeftSwipes() {
        XCTAssertEqual(SwipeToEditRowMetrics.visibleOffset(for: CGSize(width: -36, height: 4)), -36)
        XCTAssertEqual(SwipeToEditRowMetrics.visibleOffset(for: CGSize(width: -140, height: 4)), -SwipeToEditRowMetrics.actionWidth)
        XCTAssertEqual(SwipeToEditRowMetrics.visibleOffset(for: CGSize(width: 32, height: 4)), 0)
        XCTAssertEqual(SwipeToEditRowMetrics.visibleOffset(for: CGSize(width: -36, height: 44)), 0)

        XCTAssertTrue(SwipeToEditRowMetrics.shouldOpenEdit(for: CGSize(width: -72, height: 8)))
        XCTAssertFalse(SwipeToEditRowMetrics.shouldOpenEdit(for: CGSize(width: -42, height: 4)))
        XCTAssertFalse(SwipeToEditRowMetrics.shouldOpenEdit(for: CGSize(width: -72, height: 60)))
    }

    private func loadStringCatalog(relativePath: String) throws -> [String: [String: Any]] {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let catalogURL = projectRoot.appending(path: relativePath)
        let data = try Data(contentsOf: catalogURL)
        let rawJSON = try JSONSerialization.jsonObject(with: data)
        guard let catalog = rawJSON as? [String: Any],
              let strings = catalog["strings"] as? [String: [String: Any]] else {
            XCTFail("\(relativePath) has an unexpected shape")
            return [:]
        }
        return strings
    }

    private func loadProjectFile(relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: projectRoot.appending(path: relativePath), encoding: .utf8)
    }
}

private extension String {
    func utf16Offset(of needle: String) -> Int {
        let range = self.range(of: needle)!
        return range.lowerBound.utf16Offset(in: self)
    }
}
