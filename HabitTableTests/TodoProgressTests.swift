import XCTest
@testable import HabitTable

/// SwiftData 없이 정렬 규칙만 검사하기 위한 가짜 할 일
private struct TestTodo: TodoSortable {
    var id: Int
    var isDone: Bool
    var createdAt: Date
    var day: Int
}

final class TodoProgressTests: XCTestCase {
    private let cal = AppCalendar.make()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// n이 클수록 나중에 만든 것. day를 안 주면 모두 같은 날(20260928)
    private func todo(_ id: Int, done: Bool = false, created: TimeInterval? = nil, day: Int = 20260928) -> TestTodo {
        TestTodo(id: id, isDone: done, createdAt: Date(timeIntervalSince1970: created ?? TimeInterval(id)), day: day)
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

    // MARK: - 날짜별 목록

    func testItemsOnDayExcludesOtherDays() {
        let items = [todo(1, day: 20260928), todo(2, day: 20260929), todo(3, day: 20260928), todo(4, day: 20260927)]
        XCTAssertEqual(ids(TodoProgress.items(on: 20260928, from: items)), [1, 3])
        XCTAssertEqual(ids(TodoProgress.items(on: 20260929, from: items)), [2])
    }

    func testItemsOnDayAppliesSortRule() {
        let items = [
            todo(1, done: true, day: 20260928),
            todo(2, day: 20260928),
            todo(3, day: 20260929),
            todo(4, day: 20260928),
        ]
        XCTAssertEqual(ids(TodoProgress.items(on: 20260928, from: items)), [2, 4, 1])
    }

    func testItemsOnDayWithNothingIsEmpty() {
        XCTAssertEqual(ids(TodoProgress.items(on: 20261231, from: [todo(1), todo(2)])), [])
        XCTAssertEqual(ids(TodoProgress.items(on: 20260928, from: [TestTodo]())), [])
    }

    /// 날짜 기능 이전에 저장된 항목(day == 0)은 어느 날짜에도 나오지 않는다
    func testLegacyItemWithoutDayNeverShows() {
        XCTAssertEqual(ids(TodoProgress.items(on: 20260928, from: [todo(1, day: 0)])), [])
    }

    func testDayTitleRelativeDays() {
        let today = date(2026, 9, 28)
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 9, 28), today: today, calendar: cal), "오늘")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 9, 29), today: today, calendar: cal), "내일")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 9, 27), today: today, calendar: cal), "어제")
    }

    func testDayTitleOtherDaysShowMonthDayAndWeekday() {
        let today = date(2026, 9, 28) // 월요일
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 9, 30), today: today, calendar: cal), "9월 30일 (수)")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 10, 4), today: today, calendar: cal), "10월 4일 (일)")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2026, 9, 26), today: today, calendar: cal), "9월 26일 (토)")
    }

    func testDayTitleAddsYearWhenYearDiffers() {
        let today = date(2026, 12, 31)
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2027, 1, 1), today: today, calendar: cal), "내일")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2027, 1, 5), today: today, calendar: cal), "2027년 1월 5일 (화)")
        XCTAssertEqual(TodoProgress.dayTitle(for: date(2025, 12, 31), today: today, calendar: cal), "2025년 12월 31일 (수)")
    }

    func testDayTitleIgnoresTimeOfDay() {
        let today = cal.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 23, minute: 59))!
        let tomorrowMorning = cal.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 0, minute: 1))!
        XCTAssertEqual(TodoProgress.dayTitle(for: tomorrowMorning, today: today, calendar: cal), "내일")
    }
}
