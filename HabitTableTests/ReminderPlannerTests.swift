import XCTest
@testable import HabitTable

/// SwiftData 없이 계산 규칙만 검사하기 위한 가짜 습관
private struct ReminderTestHabit: HabitSchedulable {
    var weekdays: [Int]
    var createdDay: Int
    var completedDays: [Int] = []
}

final class ReminderPlannerTests: XCTestCase {
    private let cal = AppCalendar.make()
    private let everyDay = Array(1...7)

    /// 2026-09-28은 월요일. 기본 시각은 오전 8시.
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 8, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 알림 시각 기본값은 21:00
    private func planned(_ habits: [ReminderTestHabit], now: Date,
                         hour: Int = 21, minute: Int = 0, days: Int = 14) -> [Int] {
        ReminderPlanner.plannedDays(habits: habits, now: now, hour: hour, minute: minute,
                                    days: days, calendar: cal)
    }

    // MARK: - 기본

    func testDailyHabitPlansFourteenDays() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        let expected = [20260928, 20260929, 20260930] + Array(20261001...20261011)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), expected)
    }

    func testNoHabitsPlansNothing() {
        XCTAssertEqual(planned([], now: at(2026, 9, 28)), [])
    }

    func testDaysLimitCapsTheResult() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28), days: 3),
                       [20260928, 20260929, 20260930])
    }

    func testZeroDaysPlansNothing() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28), days: 0), [])
    }

    func testHabitWithNoWeekdaysPlansNothing() {
        let habit = ReminderTestHabit(weekdays: [], createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), [])
    }

    func testHabitCreatedAfterWindowPlansNothing() {
        // 14일 창은 9/28~10/11. 11/1에 만든 습관은 창 안에 해당 날짜가 없다.
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20261101)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), [])
    }

    func testTodayAlarmPassedPlansOnlyFollowingDays() {
        // 22시라 오늘(9/28) 21시 알림은 지났다. days: 3 → 9/29, 9/30만.
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28, 22, 0), days: 3),
                       [20260929, 20260930])
    }

    // MARK: - 쉬는 요일

    func testOnlyScheduledWeekdaysArePlanned() {
        // 월요일(2)만 하는 습관: 9/28(월), 10/5(월). 10/12는 15번째 날이라 범위 밖.
        let habit = ReminderTestHabit(weekdays: [2], createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), [20260928, 20261005])
    }

    func testSundayOnlyHabit() {
        // 일요일(1)만: 10/4, 10/11
        let habit = ReminderTestHabit(weekdays: [1], createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), [20261004, 20261011])
    }

    func testDayIsPlannedWhenAnyHabitIsScheduled() {
        let monday = ReminderTestHabit(weekdays: [2], createdDay: 20260901)
        let wednesday = ReminderTestHabit(weekdays: [4], createdDay: 20260901)
        // 9/28(월), 9/30(수), 10/5(월), 10/7(수)
        XCTAssertEqual(planned([monday, wednesday], now: at(2026, 9, 28), days: 10),
                       [20260928, 20260930, 20261005, 20261007])
    }

    // MARK: - 오늘: 완료 여부

    func testTodayFullyCompletedIsSkipped() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901,
                                      completedDays: [20260928])
        let result = planned([habit], now: at(2026, 9, 28))
        XCTAssertEqual(result.first, 20260929)
        XCTAssertEqual(result.count, 13)
    }

    func testTodayWithRemainingHabitIsPlanned() {
        let done = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901,
                                     completedDays: [20260928])
        let remaining = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([done, remaining], now: at(2026, 9, 28)).first, 20260928)
    }

    func testCompletionOnAnotherDayDoesNotSkipToday() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901,
                                      completedDays: [20260927])
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)).first, 20260928)
    }

    // MARK: - 오늘: 알림 시각

    func testTodayAlarmPassedIsSkipped() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28, 22, 0)).first, 20260929)
    }

    func testAlarmExactlyNowIsSkipped() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28, 21, 0)).first, 20260929)
    }

    func testAlarmOneMinuteAheadIsPlanned() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260901)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28, 20, 59)).first, 20260928)
    }

    // MARK: - 만든 날

    func testHabitCreatedLaterCountsFromCreatedDay() {
        // 9/30에 만든 매일 습관: 9/28·9/29에는 해당 없음 → 9/30부터 14일 창의 끝(10/11)까지 12일
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20260930)
        let result = planned([habit], now: at(2026, 9, 28))
        XCTAssertEqual(result.first, 20260930)
        XCTAssertEqual(result.count, 12)
    }

    // MARK: - 경계

    func testMonthAndYearBoundary() {
        let habit = ReminderTestHabit(weekdays: everyDay, createdDay: 20261201)
        XCTAssertEqual(planned([habit], now: at(2026, 12, 30), days: 4),
                       [20261230, 20261231, 20270101, 20270102])
    }

    // MARK: - 시각 변환

    func testHourMinuteFromMinutes() {
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 21 * 60).hour, 21)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 21 * 60).minute, 0)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 7 * 60 + 5).hour, 7)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 7 * 60 + 5).minute, 5)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 0).hour, 0)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 1439).hour, 23)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 1439).minute, 59)
    }

    func testHourMinuteClampsOutOfRange() {
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: -30).hour, 0)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: -30).minute, 0)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 5000).hour, 23)
        XCTAssertEqual(ReminderPlanner.hourMinute(fromMinutes: 5000).minute, 59)
    }

    func testMinutesFromDate() {
        XCTAssertEqual(ReminderPlanner.minutes(from: at(2026, 9, 28, 21, 30), calendar: cal), 21 * 60 + 30)
        XCTAssertEqual(ReminderPlanner.minutes(from: at(2026, 9, 28, 0, 0), calendar: cal), 0)
    }
}
