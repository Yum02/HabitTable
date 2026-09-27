import Foundation
import SwiftData

/// 계산 규칙(HabitProgress)이 필요로 하는 값만 모은 프로토콜.
/// 테스트에서는 SwiftData 없이 가짜 습관으로 검사할 수 있다.
protocol HabitSchedulable {
    /// 해야 하는 요일 (일=1, 월=2, … 토=7)
    var weekdays: [Int] { get }
    /// 만든 날 (DayKey, 예: 20260928)
    var createdDay: Int { get }
    /// 완료한 날짜 목록 (DayKey)
    var completedDays: [Int] { get }
}

@Model
final class Habit {
    var name: String
    var weekdays: [Int]
    var createdDay: Int
    var sortOrder: Int
    var completedDays: [Int]

    init(name: String, weekdays: [Int], createdDay: Int, sortOrder: Int = 0, completedDays: [Int] = []) {
        self.name = name
        self.weekdays = weekdays.sorted()
        self.createdDay = createdDay
        self.sortOrder = sortOrder
        self.completedDays = completedDays
    }
}

extension Habit: HabitSchedulable {}

/// 날짜를 20260928 같은 정수로 바꾼다. 시간대가 바뀌어도 하루가 밀리지 않는다.
enum DayKey {
    static func make(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
