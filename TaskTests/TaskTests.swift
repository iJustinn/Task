import XCTest
import SwiftData
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

    func testColorKeyRoundTrip() {
        for key in ColorKey.allCases {
            let raw = key.rawValue
            XCTAssertEqual(ColorKey(rawValue: raw), key)
        }
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
}

private extension String {
    func utf16Offset(of needle: String) -> Int {
        let range = self.range(of: needle)!
        return range.lowerBound.utf16Offset(in: self)
    }
}
