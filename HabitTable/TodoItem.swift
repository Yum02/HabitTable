import Foundation
import SwiftData

/// 하루짜리 일회성 할 일. 습관(Habit)과 관계 없는 독립 모델이다.
@Model
final class TodoItem {
    var title: String
    var isDone: Bool
    var createdAt: Date

    init(title: String, isDone: Bool = false, createdAt: Date = .now) {
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

extension TodoItem: TodoSortable {}
