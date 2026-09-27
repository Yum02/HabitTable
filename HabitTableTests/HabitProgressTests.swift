import XCTest
@testable import HabitTable

/// SwiftData 없이 계산 규칙만 검사하기 위한 가짜 습관
private struct TestHabit: HabitSchedulable {
    var weekdays: [Int]
    var createdDay: Int
    var completedDays: [Int] = []
}

final class HabitProgressTests: XCTestCase {
    private let cal = AppCalendar.make()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func keys(_ dates: [Date]) -> [Int] {
        dates.map { DayKey.make($0, calendar: cal) }
    }

    // MARK: - DayKey

    func testDayKey() {
        XCTAssertEqual(DayKey.make(date(2026, 9, 28), calendar: cal), 20260928)
        XCTAssertEqual(DayKey.make(date(2027, 1, 5), calendar: cal), 20270105)
    }

    // MARK: - 이번 주 (월~일)

    func testWeekStartsOnMondayMidweek() {
        // 2026-10-01 목요일 → 9/28(월) ~ 10/4(일)
        let week = HabitProgress.weekDates(containing: date(2026, 10, 1), calendar: cal)
        XCTAssertEqual(keys(week), [20260928, 20260929, 20260930, 20261001, 20261002, 20261003, 20261004])
    }

    func testWeekOnMondayAndSunday() {
        let fromMonday = HabitProgress.weekDates(containing: date(2026, 9, 28), calendar: cal)
        XCTAssertEqual(keys(fromMonday).first, 20260928)
        // 일요일은 그 주의 마지막 날 (다음 주 시작이 아님)
        let fromSunday = HabitProgress.weekDates(containing: date(2026, 10, 4), calendar: cal)
        XCTAssertEqual(keys(fromSunday).first, 20260928)
        XCTAssertEqual(keys(fromSunday).last, 20261004)
    }

    func testWeekAcrossYearEnd() {
        // 2026-12-31 목요일 → 12/28(월) ~ 2027/1/3(일)
        let week = HabitProgress.weekDates(containing: date(2026, 12, 31), calendar: cal)
        XCTAssertEqual(keys(week).first, 20261228)
        XCTAssertEqual(keys(week).last, 20270103)
    }

    // MARK: - 최근 4주 잔디

    func testLawnIsFourWeeksEndingThisWeek() {
        let lawn = HabitProgress.lawnDates(today: date(2026, 9, 30), weeks: 4, calendar: cal)
        XCTAssertEqual(lawn.count, 28)
        XCTAssertEqual(keys(lawn).first, 20260907) // 3주 전 월요일
        XCTAssertEqual(keys(lawn).last, 20261004)  // 이번 주 일요일
        XCTAssertEqual(cal.component(.weekday, from: lawn[0]), 2, "첫 칸은 월요일")
    }

    // MARK: - 해야 하는 날

    func testScheduledOnlyOnSelectedWeekdays() {
        // 월(2)·수(4)·금(6)
        let habit = TestHabit(weekdays: [2, 4, 6], createdDay: 20260901)
        XCTAssertTrue(HabitProgress.isScheduled(habit, on: date(2026, 9, 28), calendar: cal))  // 월
        XCTAssertFalse(HabitProgress.isScheduled(habit, on: date(2026, 9, 29), calendar: cal)) // 화
        XCTAssertTrue(HabitProgress.isScheduled(habit, on: date(2026, 9, 30), calendar: cal))  // 수
    }

    func testNotScheduledBeforeCreatedDay() {
        let habit = TestHabit(weekdays: Array(1...7), createdDay: 20260915)
        XCTAssertFalse(HabitProgress.isScheduled(habit, on: date(2026, 9, 14), calendar: cal))
        XCTAssertTrue(HabitProgress.isScheduled(habit, on: date(2026, 9, 15), calendar: cal))
    }

    // MARK: - 달성률

    func testProgressCountsOnlyScheduledHabits() {
        let monday = date(2026, 9, 28)
        let habits = [
            TestHabit(weekdays: Array(1...7), createdDay: 20260901, completedDays: [20260928]),
            TestHabit(weekdays: [2], createdDay: 20260901),                            // 월, 미완료
            TestHabit(weekdays: [3], createdDay: 20260901, completedDays: [20260928]), // 화 → 제외
        ]
        XCTAssertEqual(HabitProgress.progress(habits, on: monday, calendar: cal), DayProgress(done: 1, total: 2))
    }

    func testAveragePercentSkipsFutureAndEmptyDays() {
        let today = date(2026, 9, 29) // 화
        let habit = TestHabit(weekdays: [2, 3, 4], createdDay: 20260901, completedDays: [20260928])
        // 월(100%) · 화(0%) · 수(미래) · 목~일(할 습관 없음)
        let week = HabitProgress.weekDates(containing: today, calendar: cal)
        XCTAssertEqual(HabitProgress.averagePercent([habit], dates: week, today: today, calendar: cal), 50)
        let empty = TestHabit(weekdays: [1], createdDay: 20260901)
        XCTAssertNil(HabitProgress.averagePercent([empty], dates: Array(week.prefix(2)), today: today, calendar: cal))
    }

    // MARK: - 잔디 색 단계 (6단계)

    func testLevels() {
        let today = date(2026, 9, 28)
        let past = date(2026, 9, 20)
        func level(_ done: Int, _ total: Int, on day: Date = past) -> ProgressLevel {
            HabitProgress.level(for: DayProgress(done: done, total: total), date: day, today: today, calendar: cal)
        }
        XCTAssertEqual(level(0, 0), .none)
        XCTAssertEqual(level(0, 3), .zero)
        XCTAssertEqual(level(1, 3), .low)   // 33%
        XCTAssertEqual(level(1, 2), .mid)   // 50%
        XCTAssertEqual(level(2, 3), .mid)   // 67%
        XCTAssertEqual(level(3, 4), .high)  // 75%
        XCTAssertEqual(level(4, 5), .high)  // 80%
        XCTAssertEqual(level(3, 3), .full)
        XCTAssertEqual(level(0, 2, on: date(2026, 9, 29)), .future)
    }

    // MARK: - 체크 가능 여부 / 토글

    func testCanToggleOnlyTodayAndPast() {
        let today = date(2026, 9, 28)
        XCTAssertTrue(HabitProgress.canToggle(date: today, today: today, calendar: cal))
        XCTAssertTrue(HabitProgress.canToggle(date: date(2026, 8, 1), today: today, calendar: cal))
        XCTAssertFalse(HabitProgress.canToggle(date: date(2026, 9, 29), today: today, calendar: cal))
    }

    func testToggled() {
        XCTAssertEqual(HabitProgress.toggled([20260927], key: 20260928), [20260927, 20260928])
        XCTAssertEqual(HabitProgress.toggled([20260927, 20260928], key: 20260928), [20260927])
    }

    // MARK: - 요일 요약

    func testWeekdaySummary() {
        XCTAssertEqual(HabitProgress.weekdaySummary(Array(1...7)), "매일")
        XCTAssertEqual(HabitProgress.weekdaySummary([2, 3, 4, 5, 6]), "평일")
        XCTAssertEqual(HabitProgress.weekdaySummary([7, 1]), "주말")
        XCTAssertEqual(HabitProgress.weekdaySummary([6, 2, 4]), "월·수·금")
    }
}
