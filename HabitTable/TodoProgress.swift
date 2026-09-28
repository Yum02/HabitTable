import Foundation

/// 정렬 규칙(TodoProgress)이 필요로 하는 값만 모은 프로토콜.
/// 테스트에서는 SwiftData 없이 가짜 할 일로 검사할 수 있다.
protocol TodoSortable {
    var isDone: Bool { get }
    var createdAt: Date { get }
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
}
