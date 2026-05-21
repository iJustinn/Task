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

    func testColorKeyRoundTrip() {
        for key in ColorKey.allCases {
            let raw = key.rawValue
            XCTAssertEqual(ColorKey(rawValue: raw), key)
        }
    }
}
