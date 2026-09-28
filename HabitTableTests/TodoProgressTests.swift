import XCTest
@testable import HabitTable

/// SwiftData 없이 정렬 규칙만 검사하기 위한 가짜 할 일
private struct TestTodo: TodoSortable {
    var name: String
    var isDone: Bool
    var createdAt: Date
}

final class TodoProgressTests: XCTestCase {
    private func todo(_ name: String, done: Bool = false, at seconds: TimeInterval) -> TestTodo {
        TestTodo(name: name, isDone: done, createdAt: Date(timeIntervalSince1970: seconds))
    }

    private func names(_ items: [TestTodo]) -> [String] {
        items.map { $0.name }
    }

    // MARK: - sorted

    func testEmptyAndSingle() {
        XCTAssertTrue(TodoProgress.sorted([TestTodo]()).isEmpty)
        XCTAssertEqual(names(TodoProgress.sorted([todo("a", at: 1)])), ["a"])
    }

    func testUndoneComeBeforeDone() {
        let items = [
            todo("done1", done: true, at: 1),
            todo("open1", at: 2),
            todo("done2", done: true, at: 3),
            todo("open2", at: 4),
        ]
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["open1", "open2", "done1", "done2"])
    }

    func testUndoneGroupIsOrderedByCreation() {
        let items = [todo("c", at: 30), todo("a", at: 10), todo("b", at: 20)]
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["a", "b", "c"])
    }

    func testDoneGroupIsOrderedByCreation() {
        let items = [
            todo("c", done: true, at: 30),
            todo("a", done: true, at: 10),
            todo("b", done: true, at: 20),
        ]
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["a", "b", "c"])
    }

    func testSameCreatedAtKeepsInputOrder() {
        // 만든 시각이 완전히 같아도 결과가 입력 순서대로 안정적이어야 한다
        let items = [todo("first", at: 5), todo("second", at: 5), todo("third", at: 5)]
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["first", "second", "third"])
    }

    func testUndoingADoneItemRestoresItsOriginalSlot() {
        var items = [todo("a", at: 1), todo("b", at: 2), todo("c", at: 3)]
        items[0].isDone = true
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["b", "c", "a"])
        items[0].isDone = false
        XCTAssertEqual(names(TodoProgress.sorted(items)), ["a", "b", "c"])
    }

    // MARK: - normalizedTitle

    func testNormalizedTitleTrimsWhitespaceAndNewlines() {
        XCTAssertEqual(TodoProgress.normalizedTitle("  병원 예약 \n"), "병원 예약")
    }

    func testNormalizedTitleRejectsEmptyAndBlank() {
        XCTAssertNil(TodoProgress.normalizedTitle(""))
        XCTAssertNil(TodoProgress.normalizedTitle("   "))
        XCTAssertNil(TodoProgress.normalizedTitle("\n\t \n"))
    }

    func testNormalizedTitleKeepsInnerSpacesAndLongText() {
        let long = String(repeating: "택배 찾기 ", count: 60)
        XCTAssertEqual(TodoProgress.normalizedTitle(long), long.trimmingCharacters(in: .whitespaces))
        XCTAssertEqual(TodoProgress.normalizedTitle("a  b"), "a  b")
    }
}
