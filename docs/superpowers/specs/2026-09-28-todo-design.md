# 할 일(To-do) 기능 설계

## 배경과 목적

HabitTable은 지금까지 반복 습관(`Habit`)만 다뤘다. 사용자는 습관과 별개로,
하루짜리 일회성 일(예: 병원 예약, 택배 찾기)을 관리하고 싶어 한다. 이런 일은
요일 반복이나 "이번 주" 표 개념과 맞지 않으므로 완전히 독립된 기능으로
추가한다.

## 요구사항 (사용자 확정)

- 할 일은 하루짜리 일회성 작업이다. 습관처럼 반복하지 않는다.
- **(변경) 할 일마다 날짜를 지정한다.** 각 할 일은 지정한 하루의 목록에만
  보이며, 지난 날짜의 미완료 항목을 오늘로 이월하지 않는다. 처음 설계의
  "끝낼 때까지 계속 남는다"는 규칙은 폐기한다(사용자 결정).
- 원하는 날짜로 이동해 그 날의 할 일을 볼 수 있다: ‹ › 로 하루씩, 날짜를 탭해
  달력으로 점프. 새 할 일은 보고 있는 날짜에 추가된다.
- 할 일은 미리 적어 두는 용도이므로, 습관과 달리 미래 날짜도 선택하고 체크할
  수 있다.
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
| `day` | `Int` | 할 날짜(`DayKey`, 예: 20260928). 기본값 0 (아래 참고) |

요일 반복 같은 스케줄 개념은 없다. 날짜는 `Habit`과 같은 `DayKey`로 저장·비교해
시간대 문제를 피한다. `Habit`과 관계는 맺지 않는다 — 독립된 모델이다.

`day`에 기본값(0)을 둔 것은 SwiftData가 기존 저장소를 가벼운 마이그레이션으로
열 수 있게 하기 위해서다. `day == 0`인 옛 항목은 어느 날짜에도 나오지 않는다.
날짜 기능 이전에 저장된 실사용 데이터는 없다고 보고(개발 중, 배포 전) 별도
이전 로직은 만들지 않는다.

`ModelContainer`를 만드는 모든 곳에 `TodoItem.self`를 추가한다. 빠뜨리면
`@Query`가 런타임에 크래시하므로 아래 4곳을 모두 `for: Habit.self, TodoItem.self`
형태로 바꾼다:

- `HabitTableApp.swift` — 앱 본체 컨테이너
- `ContentView.swift` — `#Preview`
- `HabitBoardView.swift` — `#Preview`
- `HabitEditorView.swift` — `#Preview`(`TodoEditorView` 미리보기도 같은 형태)

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

### 날짜 이동 (`TodoListView`)

- `@State selectedDate`(처음엔 오늘). `@Query`로 전부 가져와
  `TodoProgress.items(on:from:)`으로 그 날 항목만 거른다.
- 머리글: `‹  오늘  ›` 형태. 가운데 제목은 `TodoProgress.dayTitle`이 만든다
  ("오늘"/"내일"/"어제"/"9월 30일 (수)"). 제목을 탭하면 그래픽 `DatePicker`
  시트가 열리고, 시트의 "오늘" 버튼으로 복귀할 수 있다.
- ‹ › 는 `HabitBoardView`와 같은 스타일. 미래·과거 모두 제한이 없다.
- 앱을 다시 열면(`scenePhase == .active`) 오늘로 돌아온다(`HabitBoardView`와
  같은 패턴).
- 빈 상태 카드: 오늘이면 "첫 할 일을 추가해 보세요", 다른 날이면 "이 날은
  할 일이 없어요".

### `TodoEditorView`

`HabitEditorView`와 같은 시트 패턴(취소/저장 툴바, `NavigationStack`,
`presentationDetents`)을 쓰되 요일 선택기 없이 이름 입력 필드와 날짜 한 줄
(`DatePicker`, 날짜만)만 있는 축소판이다. 새 할 일의 날짜는 목록에서 보고 있던
날짜가 기본값이고, 수정 시트에서 날짜를 바꾸면 다른 날로 옮겨진다.

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
            context.insert(TodoItem(title: trimmed, day: dayKey, createdAt: .now))
        }
        dismiss()
    }
}
```

## 계산 로직 (테스트 대상)

`TodoProgress.swift`에 순수 함수로 둔다:

```swift
protocol TodoSortable {
    var isDone: Bool { get }
    var createdAt: Date { get }
    var day: Int { get }
}

enum TodoProgress {
    /// 미완료가 위, 완료가 아래. 각 그룹은 생성순. 생성 시각이 같으면 입력 순서 유지.
    static func sorted<T: TodoSortable>(_ items: [T]) -> [T]
    /// 그 날(DayKey)의 항목만 골라 sorted 규칙으로 정렬
    static func items<T: TodoSortable>(on day: Int, from items: [T]) -> [T]
    /// "오늘" / "내일" / "어제" / "9월 30일 (수)"
    static func dayTitle(for date: Date, today: Date, calendar: Calendar) -> String
}
```

`Habit.swift`의 `DayKey`에 `make`의 역변환을 더한다:
`DayKey.date(_ key: Int, calendar: Calendar) -> Date?` (그 날 0시).
잘못된 키(예: 0, 20261399)는 nil을 돌려준다.

`HabitProgressTests`와 같은 컨벤션으로 `TodoProgressTests.swift`에 SwiftData
없는 가짜 구조체(`TodoSortable` 준수)로 테스트한다:

- 미완료가 모두 완료보다 앞에 온다.
- 미완료 그룹 안에서 생성순으로 정렬된다.
- 완료 그룹 안에서도 생성순으로 정렬된다.
- 빈 배열, 단일 항목 처리.
- `items(on:)`: 다른 날짜 항목은 섞이지 않는다 / 그 날 안에서 sorted 규칙 적용 / 항목이 없는 날은 빈 배열.
- `dayTitle`: 오늘·내일·어제·그 외(월요일 시작 달력 기준 요일)·연도 경계.
- `DayKey.date`: `make`와 왕복(월말·연말 포함), 잘못된 키는 nil.

## 에러 처리

- 빈 문자열(공백만 입력)은 저장하지 않는다 — `HabitEditorView`의 `canSave`
  패턴과 동일하게 저장 버튼을 비활성화한다.
- 삭제는 되돌릴 수 없지만 습관 삭제와 달리 확인 다이얼로그를 띄우지
  않는다(요구사항에 없었고, 할 일 하나 삭제는 습관+기록 삭제보다 손실
  체감이 작다).

## 범위 밖 (YAGNI)

- 마감일·리마인더·알림 없음 (CLAUDE.md 다음 후보 중 "알림"은 별도 기능).
  날짜는 "그 날 할 일"을 나누는 용도일 뿐 마감 개념이 아니다.
- 지난 날짜 미완료 항목의 오늘 이월, 기간(여러 날) 할 일, 반복 할 일 없음.
- 드래그 재정렬 없음 — 습관 목록도 지금 드래그 재정렬을 지원하지 않으므로
  일관성 유지.
- 카테고리·태그·우선순위 없음.
- 다크 모드는 앱 전체와 마찬가지로 라이트 모드 고정.
