# 할 일(To-do) 기능 설계

## 배경과 목적

HabitTable은 지금까지 반복 습관(`Habit`)만 다뤘다. 사용자는 습관과 별개로,
하루짜리 일회성 일(예: 병원 예약, 택배 찾기)을 관리하고 싶어 한다. 이런 일은
요일 반복이나 "이번 주" 표 개념과 맞지 않으므로 완전히 독립된 기능으로
추가한다.

## 요구사항 (사용자 확정)

- 할 일은 하루짜리 일회성 작업이다. 습관처럼 반복하지 않는다.
- 완료·삭제하기 전까지는 날짜가 지나도 계속 목록에 남는다. 특정 날짜에만
  유효한 것이 아니다.
- 화면은 습관 표와 별도 탭으로 분리한다.
- 완료한 항목은 목록에서 사라지지 않고, 줄그음 표시된 채 미완료 항목 아래로
  내려간다.
- 완료 안 한 항목이 위, 완료한 항목이 아래. 각 그룹 안에서는 만든 순서대로
  정렬한다.
- 항목 수정(이름 변경) 기능이 필요하다.

## 데이터 모델

새 SwiftData 모델 `TodoItem` (`HabitTable/TodoItem.swift`):

| 필드 | 타입 | 설명 |
|---|---|---|
| `title` | `String` | 할 일 내용 |
| `isDone` | `Bool` | 완료 여부 |
| `createdAt` | `Date` | 생성 시각. 정렬 기준으로 쓴다 |

날짜 스케줄(요일 반복, `createdDay` 이후 판정 등) 개념이 없으므로 `Habit`이
쓰는 `DayKey`/`HabitSchedulable`과는 무관하다. `Habit`과 관계도 맺지 않는다
— 완전히 독립된 모델이다.

`HabitTableApp.swift`의 `ModelContainer` 스키마에 `TodoItem.self`를 추가한다.

## 화면 구조

### 탭 전환

`ContentView`를 `TabView`로 바꾼다:

```swift
TabView {
    NavigationStack { HabitBoardView() }
        .tabItem { Label("습관", systemImage: "checkmark.square") }
    NavigationStack { TodoListView() }
        .tabItem { Label("할 일", systemImage: "list.bullet") }
}
```

탭 아이콘·라벨은 위 예시를 기본으로 하되, 구현 중 `Theme`의 기존 톤과
어울리는지 확인한다.

### `TodoListView`

- 상단: "할 일" 제목, 오른쪽 위 ＋ 버튼(툴바) — 누르면 `TodoEditorView` 새
  항목 시트.
- 항목이 하나도 없으면 습관 쪽 `emptyCard`와 같은 패턴으로 빈 상태 카드
  표시("첫 할 일을 추가해 보세요" 등).
- 목록은 `TodoProgress.sorted(_:)`로 정렬한 순서로 그린다.
- 각 행:
  - 왼쪽 체크 원(습관 표 체크와 같은 초록 계열 스타일) — 탭하면
    `isDone` 토글, `withAnimation`으로 애니메이션.
  - 텍스트 — `isDone`이면 취소선 + `Theme.stem`(흐린 색), 아니면
    `Theme.soil`.
  - 스와이프 액션: 왼쪽(leading) "수정" → `TodoEditorView(todo: item)` 시트,
    오른쪽(trailing) "삭제" → `context.delete(item)` 즉시 삭제(확인
    다이얼로그 없음 — 습관 삭제와 달리 기록 손실 우려가 적음).

### `TodoEditorView`

`HabitEditorView`와 같은 시트 패턴(취소/저장 툴바, `NavigationStack`,
`presentationDetents`)을 쓰되 요일 선택기 없이 이름 입력 필드 하나만 있는
축소판이다.

```swift
struct TodoEditorView: View {
    let todo: TodoItem?   // nil이면 새 할 일
    @State private var title: String
    ...
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let todo {
            todo.title = trimmed
        } else {
            context.insert(TodoItem(title: trimmed, isDone: false, createdAt: .now))
        }
        dismiss()
    }
}
```

## 계산 로직 (테스트 대상)

`TodoProgress.swift`에 정렬 규칙을 순수 함수로 둔다:

```swift
enum TodoProgress {
    static func sorted<T: TodoSortable>(_ items: [T]) -> [T] {
        items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            return a.createdAt < b.createdAt
        }
    }
}

protocol TodoSortable {
    var isDone: Bool { get }
    var createdAt: Date { get }
}
```

`HabitProgressTests`와 같은 컨벤션으로 `TodoProgressTests.swift`에 SwiftData
없는 가짜 구조체(`TodoSortable` 준수)로 테스트한다:

- 미완료가 모두 완료보다 앞에 온다.
- 미완료 그룹 안에서 생성순으로 정렬된다.
- 완료 그룹 안에서도 생성순으로 정렬된다.
- 빈 배열, 단일 항목 처리.

## 에러 처리

- 빈 문자열(공백만 입력)은 저장하지 않는다 — `HabitEditorView`의 `canSave`
  패턴과 동일하게 저장 버튼을 비활성화한다.
- 삭제는 되돌릴 수 없지만 습관 삭제와 달리 확인 다이얼로그를 띄우지
  않는다(요구사항에 없었고, 할 일 하나 삭제는 습관+기록 삭제보다 손실
  체감이 작다).

## 범위 밖 (YAGNI)

- 마감일·리마인더·알림 없음 (CLAUDE.md 다음 후보 중 "알림"은 별도 기능).
- 드래그 재정렬 없음 — 습관 목록도 지금 드래그 재정렬을 지원하지 않으므로
  일관성 유지.
- 카테고리·태그·우선순위 없음.
- 다크 모드는 앱 전체와 마찬가지로 라이트 모드 고정.
