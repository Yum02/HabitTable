import Foundation

/// 정렬에 필요한 값만 노출하는 프로토콜 (테스트에서 SwiftData 없이 쓰기 위함)
protocol TodoSortable {
    var isDone: Bool { get }
    var createdAt: Date { get }
}

/// 할 일의 순수 계산 규칙 — 테스트 대상
enum TodoProgress {
    /// 미완료가 위, 완료가 아래. 각 그룹 안에서는 만든 순서대로.
    /// 만든 시각이 같으면 입력 순서를 유지한다(Swift 표준 정렬은 실제로 안정적이다).
    static func sorted<T: TodoSortable>(_ items: [T]) -> [T] {
        items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            return a.createdAt < b.createdAt
        }
    }

    /// 앞뒤 공백·줄바꿈을 지운 제목. 비어 있으면 nil(저장 불가).
    static func normalizedTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
