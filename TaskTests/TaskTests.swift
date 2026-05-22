import XCTest
import SwiftData
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

    func testBoardDateSliderWindowCentersRecentDaysOnReferenceDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let may22 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 22, hour: 14)))
        let dates = BoardDateSliderDayWindow.dates(center: may22, daysBefore: 2, daysAfter: 3, calendar: calendar)

        XCTAssertEqual(dates.count, 6)
        XCTAssertEqual(dates.first, calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        XCTAssertEqual(dates[2], calendar.date(from: DateComponents(year: 2026, month: 5, day: 22)))
        XCTAssertEqual(dates.last, calendar.date(from: DateComponents(year: 2026, month: 5, day: 25)))
        XCTAssertTrue(dates.allSatisfy { calendar.isDate($0, equalTo: calendar.startOfDay(for: $0), toGranularity: .second) })
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
}
