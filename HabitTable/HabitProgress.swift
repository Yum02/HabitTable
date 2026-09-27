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

    /// 그날 해야 하는 습관인가: 요일이 맞고, 만든 날 이후
    static func isScheduled<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard DayKey.make(date, calendar: calendar) >= habit.createdDay else { return false }
        return habit.weekdays.contains(calendar.component(.weekday, from: date))
    }

    static func isCompleted<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        habit.completedDays.contains(DayKey.make(date, calendar: calendar))
    }

    /// 그날 해야 하는 습관 중 완료한 수
    static func progress<H: HabitSchedulable>(_ habits: [H], on date: Date, calendar: Calendar) -> DayProgress {
        let scheduled = habits.filter { isScheduled($0, on: date, calendar: calendar) }
        let done = scheduled.filter { isCompleted($0, on: date, calendar: calendar) }.count
        return DayProgress(done: done, total: scheduled.count)
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
