import Foundation

/// 정렬·날짜 규칙(TodoProgress)이 필요로 하는 값만 모은 프로토콜.
/// 테스트에서는 SwiftData 없이 가짜 할 일로 검사할 수 있다.
protocol TodoSortable {
    var isDone: Bool { get }
    var createdAt: Date { get }
    /// 할 날짜 (DayKey, 예: 20260928)
    var day: Int { get }
}

/// 할 일 계산 규칙 (순수 함수)
enum TodoProgress {
    /// 미완료가 위, 완료가 아래. 각 그룹 안에서는 만든 순서.
    /// 생성 시각이 같으면 입력 순서를 유지한다(Swift의 sorted는 안정 정렬).
    static func sorted<T: TodoSortable>(_ items: [T]) -> [T] {
        items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            return a.createdAt < b.createdAt
        }
    }

    /// 그 날(DayKey)의 할 일만 골라 sorted 규칙으로 정렬한다.
    static func items<T: TodoSortable>(on day: Int, from items: [T]) -> [T] {
        sorted(items.filter { $0.day == day })
    }

    /// 날짜 머리글: "오늘" / "내일" / "어제" / "9월 30일 (수)".
    /// 올해가 아니면 "2027년 1월 5일 (화)"처럼 연도를 붙인다.
    static func dayTitle(for date: Date, today: Date, calendar: Calendar) -> String {
        let target = calendar.startOfDay(for: date)
        let base = calendar.startOfDay(for: today)
        switch calendar.dateComponents([.day], from: base, to: target).day ?? 0 {
        case 0: return "오늘"
        case 1: return "내일"
        case -1: return "어제"
        default:
            let c = calendar.dateComponents([.year, .month, .day, .weekday], from: target)
            let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]   // 일=1 … 토=7
            let weekday = weekdayNames[((c.weekday ?? 1) - 1) % 7]
            let monthDay = "\(c.month ?? 0)월 \(c.day ?? 0)일 (\(weekday))"
            return c.year == calendar.component(.year, from: base) ? monthDay : "\(c.year ?? 0)년 \(monthDay)"
        }
    }

    /// 할 일이 없는 날의 빈 화면 문구 (day·today는 DayKey).
    /// 오늘은 첫 안내, 앞으로의 날은 "미리 적어 둘", 지난 날은 "한 일을 적어 둘 수도".
    static func emptyState(day: Int, today: Int) -> (title: String, message: String) {
        if day == today {
            return ("오늘 할 일을 추가해 보세요",
                    "병원 예약, 택배 찾기처럼 하루짜리 일을 적어 두세요. 위의 날짜를 눌러 다른 날 할 일도 볼 수 있어요.")
        }
        if day > today {
            return ("이 날은 할 일이 없어요", "아래 버튼으로 이 날 할 일을 미리 적어 둘 수 있어요.")
        }
        return ("이 날은 할 일이 없어요", "아래 버튼으로 이 날 한 일을 적어 둘 수도 있어요.")
    }
}
