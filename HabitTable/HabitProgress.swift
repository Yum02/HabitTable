import Foundation

/// 앱 전체에서 쓰는 달력: 그레고리력, 한국어, 월요일 시작
enum AppCalendar {
    static func make() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ko_KR")
        cal.timeZone = .current
        cal.firstWeekday = 2 // 월요일
        return cal
    }
}

/// 하루 달성 현황
struct DayProgress: Equatable {
    let done: Int
    let total: Int
}

/// 잔디 색 단계
enum ProgressLevel: Equatable {
    case none    // 할 습관 없음
    case zero    // 0%
    case low     // 1–49%
    case mid     // 50–74%
    case high    // 75–99%
    case full    // 100%
    case future  // 아직 안 온 날
}

/// 습관 계산 규칙 모음 (화면 코드와 분리해 단위 테스트한다)
enum HabitProgress {

    // MARK: - 날짜 범위

    /// date가 속한 주의 월~일 7일
    static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)   // 일=1 … 토=7
        let offsetFromMonday = (weekday + 5) % 7                  // 월=0 … 일=6
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// 이번 주로 끝나는 최근 n주 (월요일부터, n×7일)
    static func lawnDates(today: Date, weeks: Int, calendar: Calendar) -> [Date] {
        guard let thisMonday = weekDates(containing: today, calendar: calendar).first,
              let start = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: thisMonday)
        else { return [] }
        return (0..<(weeks * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: - 습관 판정

    /// 그날 꼭 해야 하는 습관인가: 요일 방식이고, 요일이 맞고, 만든 날 이후.
    /// 주 n회 습관은 정해진 요일이 없으므로 항상 false (isCheckable·countsToward 참고)
    static func isScheduled<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard habit.weeklyTarget == nil,
              DayKey.make(date, calendar: calendar) >= habit.createdDay else { return false }
        return habit.weekdays.contains(calendar.component(.weekday, from: date))
    }

    static func isCompleted<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        habit.completedDays.contains(DayKey.make(date, calendar: calendar))
    }

    /// 그날 달성률에 들어가는 습관 중 완료한 수
    static func progress<H: HabitSchedulable>(_ habits: [H], on date: Date, calendar: Calendar) -> DayProgress {
        let counted = habits.filter { countsToward($0, on: date, calendar: calendar) }
        let done = counted.filter { isCompleted($0, on: date, calendar: calendar) }.count
        return DayProgress(done: done, total: counted.count)
    }

    /// 오늘까지, 할 습관이 있던 날들의 평균 달성률(%). 그런 날이 없으면 nil
    static func averagePercent<H: HabitSchedulable>(_ habits: [H], dates: [Date], today: Date, calendar: Calendar) -> Int? {
        let todayKey = DayKey.make(today, calendar: calendar)
        let rates: [Double] = dates.compactMap { date in
            guard DayKey.make(date, calendar: calendar) <= todayKey else { return nil }
            let p = progress(habits, on: date, calendar: calendar)
            return p.total == 0 ? nil : Double(p.done) / Double(p.total)
        }
        guard !rates.isEmpty else { return nil }
        return Int((rates.reduce(0, +) / Double(rates.count) * 100).rounded())
    }

    // MARK: - 주 n회

    static let weeklyTargetRange = 1...6

    /// 표에 체크 칸을 보여 줄 날인가: 만든 날 이후이고, 주 n회이거나 요일이 맞는다
    static func isCheckable<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard DayKey.make(date, calendar: calendar) >= habit.createdDay else { return false }
        return habit.weeklyTarget != nil || habit.weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// 하루 달성률에 넣는가: 그날 해야 하는 요일 습관이거나, 그날 체크한 주 n회 습관
    static func countsToward<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard habit.weeklyTarget != nil else { return isScheduled(habit, on: date, calendar: calendar) }
        return DayKey.make(date, calendar: calendar) >= habit.createdDay
            && isCompleted(habit, on: date, calendar: calendar)
    }

    /// date가 속한 월~일 주에 완료한 날 수. 만든 날 이전 기록과 중복 날짜는 세지 않는다.
    static func weeklyCount<H: HabitSchedulable>(_ habit: H, weekContaining date: Date, calendar: Calendar) -> Int {
        let week = weekDates(containing: date, calendar: calendar)
        guard let first = week.first, let last = week.last else { return 0 }
        let from = max(DayKey.make(first, calendar: calendar), habit.createdDay)
        let to = DayKey.make(last, calendar: calendar)
        return Set(habit.completedDays).filter { $0 >= from && $0 <= to }.count
    }

    /// 알림 대상인 주 n회 습관인가: 만든 날 이후, 그날 미완료, 그 주 목표 미달
    static func isWeeklyPending<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard let target = habit.weeklyTarget,
              DayKey.make(date, calendar: calendar) >= habit.createdDay,
              !isCompleted(habit, on: date, calendar: calendar) else { return false }
        return weeklyCount(habit, weekContaining: date, calendar: calendar) < target
    }

    /// "주 3회 · 2/3"
    static func weeklySummary(target: Int, count: Int) -> String {
        "주 \(target)회 · \(count)/\(target)"
    }

    // MARK: - 연속 기록

    /// 오늘 기준 연속 기록. 요일 습관은 해야 하는 날 수, 주 n회 습관은 목표를 채운 주 수.
    /// 오늘(이번 주)이 아직 미완료(미달)면 끊지 않고 건너뛴다. 만든 날 이전은 보지 않는다.
    static func streak<H: HabitSchedulable>(_ habit: H, today: Date, calendar: Calendar) -> Int {
        habit.weeklyTarget == nil
            ? dailyStreak(habit, today: today, calendar: calendar)
            : weeklyStreak(habit, today: today, calendar: calendar)
    }

    /// 오늘부터 하루씩 거꾸로: 쉬는 요일은 건너뛰고, 해야 하는 날을 놓치면 멈춘다
    private static func dailyStreak<H: HabitSchedulable>(_ habit: H, today: Date, calendar: Calendar) -> Int {
        let done = Set(habit.completedDays)
        var day = calendar.startOfDay(for: today)
        var isToday = true
        var count = 0
        while DayKey.make(day, calendar: calendar) >= habit.createdDay {
            if isScheduled(habit, on: day, calendar: calendar) {
                if done.contains(DayKey.make(day, calendar: calendar)) {
                    count += 1
                } else if !isToday {
                    break
                }
            }
            isToday = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// 이번 주부터 한 주씩 거꾸로: 목표를 못 채운 주에서 멈춘다
    private static func weeklyStreak<H: HabitSchedulable>(_ habit: H, today: Date, calendar: Calendar) -> Int {
        guard let target = habit.weeklyTarget,
              var monday = weekDates(containing: today, calendar: calendar).first else { return 0 }
        var isThisWeek = true
        var count = 0
        while let sunday = calendar.date(byAdding: .day, value: 6, to: monday),
              DayKey.make(sunday, calendar: calendar) >= habit.createdDay {
            if weeklyCount(habit, weekContaining: monday, calendar: calendar) >= target {
                count += 1
            } else if !isThisWeek {
                break
            }
            isThisWeek = false
            guard let previous = calendar.date(byAdding: .day, value: -7, to: monday) else { break }
            monday = previous
        }
        return count
    }

    /// 2 이상이면 "🌱5", 아니면 nil (배지를 숨긴다)
    static func streakBadge(_ count: Int) -> String? {
        count >= 2 ? "🌱\(count)" : nil
    }

    /// 접근성용 "5일 연속" / "3주 연속"
    static func streakSpoken(_ count: Int, weekly: Bool) -> String {
        "\(count)\(weekly ? "주" : "일") 연속"
    }

    // MARK: - 색 단계

    static func level(for progress: DayProgress, date: Date, today: Date, calendar: Calendar) -> ProgressLevel {
        if DayKey.make(date, calendar: calendar) > DayKey.make(today, calendar: calendar) { return .future }
        if progress.total == 0 { return .none }
        if progress.done == 0 { return .zero }
        if progress.done >= progress.total { return .full }
        if progress.done * 2 < progress.total { return .low }      // < 50%
        if progress.done * 4 < progress.total * 3 { return .mid }  // < 75%
        return .high
    }

    // MARK: - 체크

    /// 오늘과 지난 날짜만 체크할 수 있다
    static func canToggle(date: Date, today: Date, calendar: Calendar) -> Bool {
        DayKey.make(date, calendar: calendar) <= DayKey.make(today, calendar: calendar)
    }

    /// 완료 목록에 key가 있으면 빼고, 없으면 넣는다
    static func toggled(_ days: [Int], key: Int) -> [Int] {
        days.contains(key) ? days.filter { $0 != key } : (days + [key]).sorted()
    }

    // MARK: - 표시용

    /// 이번 주 표의 이름 칸 너비. 표 폭(카드 포함)에서 여백(16)·이름 칸 왼쪽 여백(4)과
    /// 날짜 칸 7개(누르는 영역 34pt)를 먼저 남기고, 남는 폭을 82~100pt 안에서 쓴다.
    static func nameColumnWidth(tableWidth: CGFloat) -> CGFloat {
        let spare = tableWidth - 16 - 4 - 7 * 34
        return min(max(spare, 82), 100)
    }

    /// [2,4,6] → "월·수·금", 7일 → "매일"
    static func weekdaySummary(_ weekdays: [Int]) -> String {
        let set = Set(weekdays)
        if set == Set(1...7) { return "매일" }
        if set == Set(2...6) { return "평일" }
        if set == [1, 7] { return "주말" }
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return [2, 3, 4, 5, 6, 7, 1].filter(set.contains).map { names[$0 - 1] }.joined(separator: "·")
    }
}
