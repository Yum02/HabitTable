import XCTest
@testable import HabitTable

/// SwiftData 없이 계산 규칙만 검사하기 위한 가짜 습관
private struct TestHabit: HabitSchedulable {
    var weekdays: [Int]
    var createdDay: Int
    var completedDays: [Int] = []
    var weeklyTarget: Int? = nil
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

    func testDayKeyDateRoundTrip() {
        for (y, m, d) in [(2026, 9, 28), (2026, 1, 31), (2026, 2, 28), (2028, 2, 29), (2026, 12, 31), (2027, 1, 1)] {
            let key = DayKey.make(date(y, m, d), calendar: cal)
            let back = DayKey.date(key, calendar: cal)
            XCTAssertEqual(back.map { DayKey.make($0, calendar: cal) }, key, "\(y)-\(m)-\(d)")
            XCTAssertEqual(back, cal.startOfDay(for: date(y, m, d)), "\(y)-\(m)-\(d)")
        }
    }

    func testDayKeyDateRejectsInvalidKeys() {
        XCTAssertNil(DayKey.date(0, calendar: cal))
        XCTAssertNil(DayKey.date(20261399, calendar: cal))   // 13월
        XCTAssertNil(DayKey.date(20260230, calendar: cal))   // 2월 30일
        XCTAssertNil(DayKey.date(20270229, calendar: cal))   // 평년 2월 29일
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

    // MARK: - 주 n회

    /// 실제 앱처럼 weekdays는 월~일 전체로 둔다(편집 시트 기본값·샘플 데이터와 같음).
    /// 그래야 isScheduled의 `weeklyTarget == nil` 조건이 빠졌을 때 테스트가 실패한다.
    private func weekly(_ target: Int, created: Int = 20260901, done: [Int] = []) -> TestHabit {
        TestHabit(weekdays: Array(1...7), createdDay: created, completedDays: done, weeklyTarget: target)
    }

    func testWeeklyHabitIsNeverScheduledButCheckableAfterCreation() {
        let habit = weekly(3, created: 20260930)   // 9/30(수)에 만듦
        for d in 28...30 {
            XCTAssertFalse(HabitProgress.isScheduled(habit, on: date(2026, 9, d), calendar: cal), "9/\(d)")
        }
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 28), calendar: cal))
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 29), calendar: cal))
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 9, 30), calendar: cal))
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 10, 4), calendar: cal), "일요일도 체크 칸")
    }

    func testWeekdayHabitCheckableMatchesScheduled() {
        let habit = TestHabit(weekdays: [2, 4, 6], createdDay: 20260901)   // 월·수·금
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 9, 28), calendar: cal))
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 29), calendar: cal))
    }

    func testWeeklyHabitCountsOnlyOnCheckedDays() {
        let habit = weekly(3, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 1, total: 1))
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 30), calendar: cal), DayProgress(done: 0, total: 0))
    }

    func testWeeklyMixedWithWeekdayHabit() {
        let daily = TestHabit(weekdays: Array(1...7), createdDay: 20260901)
        let habit = weekly(3, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([daily, habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 1, total: 2))
        XCTAssertEqual(HabitProgress.progress([daily, habit], on: date(2026, 9, 30), calendar: cal), DayProgress(done: 0, total: 1))
    }

    func testWeeklyCheckBeforeCreationDoesNotCount() {
        let habit = weekly(3, created: 20261001, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 0, total: 0))
    }

    func testWeeklyOnlyUncheckedWeekHasNoAverage() {
        let habit = weekly(3)
        let week = HabitProgress.weekDates(containing: date(2026, 9, 30), calendar: cal)
        XCTAssertNil(HabitProgress.averagePercent([habit], dates: week, today: date(2026, 10, 4), calendar: cal))
        let p = HabitProgress.progress([habit], on: date(2026, 9, 30), calendar: cal)
        XCTAssertEqual(HabitProgress.level(for: p, date: date(2026, 9, 30), today: date(2026, 10, 4), calendar: cal), .none)
    }

    func testWeeklyCountOnlyThatWeek() {
        // 9/27(일)은 지난주, 10/5(월)는 다음 주
        let habit = weekly(3, done: [20260927, 20260928, 20260930, 20261004, 20261005])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 1), calendar: cal), 3)
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 4), calendar: cal), 3, "일요일은 같은 주")
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 5), calendar: cal), 1, "월요일부터 새로 센다")
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 27), calendar: cal), 1)
    }

    func testWeeklyCountExcludesBeforeCreation() {
        let habit = weekly(3, created: 20260930, done: [20260928, 20260930])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 1), calendar: cal), 1)
    }

    func testWeeklyCountIncludesChecksFromWeekdayEra() {
        // 월요일 습관(요일 방식)으로 9/28에 체크한 뒤 주 3회로 바꿈. createdDay는 그대로라 그 체크도 센다.
        let habit = TestHabit(weekdays: [2], createdDay: 20260901,
                              completedDays: [20260928, 20260930], weeklyTarget: 3)
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 1), calendar: cal), 2)
    }

    func testWeeklyCountAllowsOverTarget() {
        let habit = weekly(2, done: [20260928, 20260929, 20260930])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 28), calendar: cal), 3)
    }

    func testWeeklyCountIgnoresDuplicateKeys() {
        let habit = weekly(3, done: [20260928, 20260928])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 28), calendar: cal), 1)
    }

    func testWeeklyCountAcrossYearEnd() {
        // 2026-12-28(월) ~ 2027-01-03(일)이 한 주
        let habit = weekly(3, done: [20261228, 20270103, 20270104])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 12, 31), calendar: cal), 2)
    }

    func testIsWeeklyPending() {
        let once = weekly(2, done: [20260928])
        XCTAssertFalse(HabitProgress.isWeeklyPending(once, on: date(2026, 9, 28), calendar: cal), "그날 이미 완료")
        XCTAssertTrue(HabitProgress.isWeeklyPending(once, on: date(2026, 9, 29), calendar: cal), "목표 전")

        let met = weekly(2, done: [20260928, 20260929])
        XCTAssertFalse(HabitProgress.isWeeklyPending(met, on: date(2026, 9, 30), calendar: cal), "목표 달성")
        XCTAssertTrue(HabitProgress.isWeeklyPending(met, on: date(2026, 10, 5), calendar: cal), "다음 주는 새로")

        let notYet = weekly(2, created: 20261001)
        XCTAssertFalse(HabitProgress.isWeeklyPending(notYet, on: date(2026, 9, 30), calendar: cal), "만들기 전")

        let weekday = TestHabit(weekdays: Array(1...7), createdDay: 20260901)
        XCTAssertFalse(HabitProgress.isWeeklyPending(weekday, on: date(2026, 9, 30), calendar: cal), "요일 습관은 해당 없음")
    }

    func testWeeklySummary() {
        XCTAssertEqual(HabitProgress.weeklySummary(target: 3, count: 2), "주 3회 · 2/3")
        XCTAssertEqual(HabitProgress.weeklySummary(target: 2, count: 4), "주 2회 · 4/2")
    }

    // MARK: - 연속 기록

    private func streak(_ habit: TestHabit, today: Date) -> Int {
        HabitProgress.streak(habit, today: today, calendar: cal)
    }

    /// 월·수·금 습관
    private func mwf(created: Int = 20260901, _ done: [Int]) -> TestHabit {
        TestHabit(weekdays: [2, 4, 6], createdDay: created, completedDays: done)
    }

    // 주 n회 습관은 파일에 이미 있는 weekly(_:created:done:) 헬퍼를 쓴다

    func testStreakDailySkipsRestDays() {
        // 9/28(월) 9/30(수) 10/2(금) 10/5(월) 완료, 오늘 10/6(화)은 쉬는 날
        let h = mwf([20260928, 20260930, 20261002, 20261005])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 4)
    }

    func testStreakDailyKeepsWhenTodayUndone() {
        // 오늘 10/7(수) 아직 안 함 → 어제까지 4 유지, 하면 5
        var h = mwf([20260928, 20260930, 20261002, 20261005])
        XCTAssertEqual(streak(h, today: date(2026, 10, 7)), 4)
        h.completedDays.append(20261007)
        XCTAssertEqual(streak(h, today: date(2026, 10, 7)), 5)
    }

    func testStreakDailyBreaksOnMissedDay() {
        // 9/30(수)을 놓침 → 10/5, 10/2 두 번
        XCTAssertEqual(streak(mwf([20260928, 20261002, 20261005]), today: date(2026, 10, 5)), 2)
        // 바로 전 해야 하는 날(10/5)을 놓치고 오늘 10/7 완료 → 1
        XCTAssertEqual(streak(mwf([20261002, 20261007]), today: date(2026, 10, 7)), 1)
        // 아무것도 안 함 → 0
        XCTAssertEqual(streak(mwf([]), today: date(2026, 10, 7)), 0)
    }

    func testStreakDailyStopsAtCreatedDay() {
        // 10/2에 만듦 → 그 전 기록(9/28, 9/30)은 세지 않음
        let h = mwf(created: 20261002, [20260928, 20260930, 20261002, 20261005])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 2)
    }

    func testStreakDailyIgnoresRestDayChecks() {
        // 9/29(화, 쉬는 날) 체크는 더하지 않음
        XCTAssertEqual(streak(mwf([20260928, 20260929, 20260930]), today: date(2026, 9, 30)), 2)
        // 오늘 10/6(화, 쉬는 날)이 체크돼 있어도 +1 하지 않음
        XCTAssertEqual(streak(mwf([20261005, 20261006]), today: date(2026, 10, 6)), 1)
    }

    func testStreakDailyAcrossYearEnd() {
        let h = TestHabit(weekdays: Array(1...7), createdDay: 20261201,
                          completedDays: [20261230, 20261231, 20270101])
        XCTAssertEqual(streak(h, today: date(2027, 1, 1)), 3)
    }

    func testStreakDailyEmptyWeekdaysIsZero() {
        let h = TestHabit(weekdays: [], createdDay: 20260901, completedDays: [20261005, 20261006])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 0)
    }

    func testStreakWeeklyCountsMetWeeks() {
        // 주 2회: 9/21 주 2번, 9/28 주 2번, 이번 주(10/5~) 0번 → 이번 주는 건너뛰고 2
        var h = weekly(2, created: 20260921, done: [20260922, 20260924, 20260929, 20261003])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 2)
        // 이번 주도 채우면 3
        h.completedDays += [20261005, 20261006]
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 3)
    }

    func testStreakWeeklyBreaksOnMissedWeek() {
        // 9/28 주는 1번뿐 → 거기서 멈춤
        var h = weekly(2, created: 20260921, done: [20260922, 20260924, 20260929])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 0)
        h.completedDays += [20261005, 20261006]
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 1)
    }

    func testStreakWeeklyMondayBoundary() {
        // 10/4(일)과 10/5(월)는 다른 주: 9/28 주 2번(9/29, 10/4), 이번 주 1번 → 1
        let h = weekly(2, created: 20260928, done: [20260929, 20261004, 20261005])
        XCTAssertEqual(streak(h, today: date(2026, 10, 5)), 1)
    }

    func testStreakWeeklyAcrossYearEnd() {
        // 12/28(월)과 2027-01-03(일)은 같은 주
        let h = weekly(2, created: 20261201, done: [20261228, 20270103])
        XCTAssertEqual(streak(h, today: date(2027, 1, 3)), 1)
    }

    func testStreakWeeklyCreatedMidWeek() {
        // 10/4(일)에 만듦: 그 주는 10/4 하루뿐이라 2번을 못 채움 → 연속은 이번 주부터
        // 만든 날 이전 기록(9/22, 9/23)은 세지 않음
        var h = weekly(2, created: 20261004, done: [20260922, 20260923, 20261004, 20261005, 20261006])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 1)
        // 이번 주도 아직 못 채웠으면 0
        h.completedDays = [20260922, 20260923, 20261004, 20261005]
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 0)
    }

    func testStreakRecalculatesAfterSettingsChange() {
        // 같은 기록, 요일 방식(매일) ↔ 주 2회: 단위가 바뀌어 다시 계산
        var h = TestHabit(weekdays: Array(1...7), createdDay: 20260901, completedDays: [20261005, 20261006])
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 2)   // 2일
        h.weeklyTarget = 2
        XCTAssertEqual(streak(h, today: date(2026, 10, 6)), 1)   // 1주

        // 요일 월·수·금 → 화·목: 과거 날짜도 새 요일로 판정
        var d = mwf([20260928, 20260930, 20261002, 20261005])
        XCTAssertEqual(streak(d, today: date(2026, 10, 5)), 4)
        d.weekdays = [3, 5]
        XCTAssertEqual(streak(d, today: date(2026, 10, 5)), 0)

        // 목표 2회 → 3회: 지난주들도 3회 기준
        var w = weekly(2, created: 20260921, done: [20260922, 20260924, 20260929, 20261001])
        XCTAssertEqual(streak(w, today: date(2026, 10, 6)), 2)
        w.weeklyTarget = 3
        XCTAssertEqual(streak(w, today: date(2026, 10, 6)), 0)
    }

    func testStreakBadgeAndSpoken() {
        XCTAssertNil(HabitProgress.streakBadge(0))
        XCTAssertNil(HabitProgress.streakBadge(1))
        XCTAssertEqual(HabitProgress.streakBadge(2), "🌱2")
        XCTAssertEqual(HabitProgress.streakBadge(12), "🌱12")
        XCTAssertEqual(HabitProgress.streakSpoken(5, weekly: false), "5일 연속")
        XCTAssertEqual(HabitProgress.streakSpoken(3, weekly: true), "3주 연속")
    }
}
