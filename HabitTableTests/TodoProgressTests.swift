import XCTest
@testable import HabitTable

/// SwiftData 없이 정렬 규칙만 검사하기 위한 가짜 할 일
private struct TestTodo: TodoSortable {
    var id: Int
    var isDone: Bool
    var createdAt: Date
}

final class TodoProgressTests: XCTestCase {
    /// n이 클수록 나중에 만든 것
    private func todo(_ id: Int, done: Bool = false, created: TimeInterval? = nil) -> TestTodo {
        TestTodo(id: id, isDone: done, createdAt: Date(timeIntervalSince1970: created ?? TimeInterval(id)))
    }

    private func ids(_ items: [TestTodo]) -> [Int] { items.map(\.id) }

    func testEmptyAndSingle() {
        XCTAssertEqual(ids(TodoProgress.sorted([TestTodo]())), [])
        XCTAssertEqual(ids(TodoProgress.sorted([todo(1)])), [1])
        XCTAssertEqual(ids(TodoProgress.sorted([todo(1, done: true)])), [1])
    }

    func testUndoneComesBeforeDone() {
        let items = [todo(1, done: true), todo(2), todo(3, done: true), todo(4)]
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [2, 4, 1, 3])
    }

    func testUndoneGroupSortedByCreation() {
        let items = [todo(3), todo(1), todo(2)]
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [1, 2, 3])
    }

    func testDoneGroupSortedByCreation() {
        let items = [todo(3, done: true), todo(1, done: true), todo(2, done: true)]
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [1, 2, 3])
    }

    /// 완료했다가 되돌린 항목은 맨 아래가 아니라 생성순 자리로 돌아온다
    func testUncheckedItemReturnsToCreationPosition() {
        var items = [todo(1), todo(2), todo(3)]
        items[0].isDone = true
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [2, 3, 1])
        items[0].isDone = false
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [1, 2, 3])
    }

    /// 생성 시각이 같으면 들어온 순서를 유지한다 (화면이 매번 같은 순서로 나오도록)
    func testEqualCreationTimeKeepsInputOrder() {
        let items = [todo(7, created: 100), todo(5, created: 100), todo(6, created: 100)]
        XCTAssertEqual(ids(TodoProgress.sorted(items)), [7, 5, 6])
    }
}
