import Foundation

/// 알림 계산 규칙 (화면·알림 센터 코드와 분리해 단위 테스트한다)
enum ReminderPlanner {

    /// 오늘부터 `days`일 중 알림을 예약할 날짜(DayKey). 오름차순.
    /// - 그날 해야 하는 습관이 없으면 제외한다.
    /// - 오늘은 알림 시각이 아직 미래이고, 오늘 할 습관 중 체크 안 한 게 있을 때만 포함한다.
    static func plannedDays<H: HabitSchedulable>(
        habits: [H], now: Date, hour: Int, minute: Int,
        days: Int = 14, calendar: Calendar
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        var result: [Int] = []
        for offset in 0..<max(days, 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let scheduled = habits.filter { HabitProgress.isScheduled($0, on: day, calendar: calendar) }
            guard !scheduled.isEmpty else { continue }
            if offset == 0 {
                guard let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      fire > now,
                      scheduled.contains(where: { !HabitProgress.isCompleted($0, on: day, calendar: calendar) })
                else { continue }
            }
            result.append(DayKey.make(day, calendar: calendar))
        }
        return result
    }

    // MARK: - 시각 변환 (설정에는 0시부터의 분으로 저장한다)

    /// 0…1439로 보정한 뒤 시·분으로 나눈다.
    static func hourMinute(fromMinutes minutes: Int) -> (hour: Int, minute: Int) {
        let m = min(max(minutes, 0), 24 * 60 - 1)
        return (m / 60, m % 60)
    }

    static func minutes(from date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
