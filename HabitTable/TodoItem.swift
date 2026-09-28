import Foundation
import SwiftData

/// 하루짜리 일회성 할 일. 습관(Habit)과 관계 없는 독립 모델이다.
@Model
final class TodoItem {
    var title: String
    var isDone: Bool
    var createdAt: Date
    /// 할 날짜 (DayKey, 예: 20260928). 기본값 0은 SwiftData가 기존 저장소를
    /// 가벼운 마이그레이션으로 열기 위한 것이며, 0인 옛 항목은 어느 날짜에도 나오지 않는다.
    var day: Int = 0

    init(title: String, day: Int, isDone: Bool = false, createdAt: Date = .now) {
        self.title = title
        self.day = day
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

extension TodoItem: TodoSortable {}
