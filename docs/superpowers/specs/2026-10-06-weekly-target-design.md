# 주 n회 목표 설계

## 배경과 목적

지금 습관은 "월·수·금"처럼 요일을 정해야 한다. 요일이 매번 달라지는 습관(운동,
명상 등)은 기록하기 어렵다. 그래서 "일주일에 n번, 아무 요일이나" 방식을 추가한다.

세 기능(주 n회 → 연속 기록 → 위젯) 중 첫 번째다. 나머지 둘은 이 규칙을 따르므로
따로 설계한다. 이번 범위에 연속 기록과 위젯은 없다.

## 요구사항 (사용자 확정)

- 습관마다 **요일 정하기** 또는 **주 n회** 중 하나를 고른다. 기존 습관은 요일 방식
  그대로 동작한다.
- n은 1~6이다(7은 요일 방식의 "매일"과 같으므로 두지 않는다). 새로 고를 때 기본 3.
- 주는 월~일이다(`AppCalendar`와 같음).
- **하루 달성률·잔디**: 주 n회 습관은 **체크한 날에만** 계산에 들어간다
  (그날 done +1, total +1). 체크하지 않은 날은 계산에서 빠진다.
- **알림**: 주 n회 습관은 그 주 목표를 못 채웠고 그날 체크하지 않았으면 알림 대상이다.
  목표를 채우면 그 주의 남은 날에는 대상이 아니다.
- 주 중간에 만든 습관도 그 주 목표는 n 그대로다(날짜 비례로 줄이지 않는다).
- 목표보다 많이 해도 된다. 횟수는 실제 값(예: 4/3)을 보여 준다.
- 수정에서 방식을 바꿔도 체크 기록(`completedDays`)은 그대로 둔다.

## 데이터

```swift
protocol HabitSchedulable {
    var weekdays: [Int] { get }
    var createdDay: Int { get }
    var completedDays: [Int] { get }
    /// nil이면 요일 방식, 1~6이면 주 n회 방식
    var weeklyTarget: Int? { get }
}

@Model final class Habit {
    // 기존 속성 …
    var weeklyTarget: Int? = nil
    init(name:weekdays:createdDay:sortOrder:completedDays:weeklyTarget: Int? = nil)
}
```

- 선택형 속성 추가라 SwiftData 경량 마이그레이션으로 기존 데이터는 `nil`이 된다.
  별도 마이그레이션 코드는 없다.
- 주 n회 습관의 `weekdays`는 계산에 쓰지 않는다. 편집 화면에서 고른 값을 그대로
  저장해 두어, 요일 방식으로 되돌릴 때 이전 선택이 남게 한다.

## 계산 규칙 (`HabitProgress`)

| 함수 | 규칙 |
|---|---|
| `weeklyTargetRange` | `1...6` |
| `isScheduled(h, on:)` | **그날 꼭 해야 하는 습관.** 요일 방식: 만든 날 이후 + 요일 일치(지금과 같음). 주 n회: 항상 `false`. |
| `isCheckable(h, on:)` (새) | 표에서 체크 칸을 보여 줄지. 만든 날 이후이고, 주 n회이거나 요일이 맞으면 `true`. |
| `countsToward(h, on:)` (새) | 하루 달성률에 넣을지. `isScheduled` 이거나, 주 n회이면서 만든 날 이후이고 그날 완료. |
| `progress(_:on:)` | `countsToward`인 습관만 모아 done/total을 센다. |
| `weeklyCount(h, weekContaining:)` (새) | 그 날짜가 속한 월~일 주에서 완료한 날 수. 만든 날 이전 기록은 세지 않는다. |
| `isWeeklyPending(h, on:)` (새) | 주 n회이고, 만든 날 이후이고, 그날 미완료이고, `weeklyCount < target`. |
| `weeklySummary(target:count:)` (새) | `"주 3회 · 2/3"` 표시 문자열. |

`averagePercent`, `level`은 `progress`를 쓰므로 바꾸지 않는다.

## 알림 (`ReminderPlanner.plannedDays`)

그날의 대상 습관을 `isScheduled || isWeeklyPending`으로 고른다. 대상이 없으면 그날은
뺀다. 오늘(offset 0)은 지금처럼 "알림 시각이 미래이고 대상 중 미완료가 있을 때"만
넣는다. 주 n회 대상은 정의상 그날 미완료다.

`HabitBoardView`의 재예약 비교 키에 `weeklyTarget`을 넣어, 방식·횟수를 바꾸면 다시
예약되게 한다.

## 화면

**이번 주 표 (`WeekMatrixView`)**
- 칸 상태: `isCheckable`이 아니면 "–", 미래면 점선, 아니면 완료/미완료.
  (주 n회 습관은 만든 날 이후 모든 요일이 체크 칸이다.)
- 주 n회 습관은 이름 아래 작은 글씨(`.spoqa(10, .medium, relativeTo: .caption2)`)로
  `weeklySummary`를 표시한다. 줄 높이 34 안에 두 줄로 넣고 이름 칸 너비는 그대로다.
- 목표를 채우면 표시가 `Theme.grass4` + ✓, 못 채우면 `Theme.stem`.
- 보고 있는 주(‹ ›로 넘긴 주 포함)의 횟수를 보여 준다.
- 접근성: 이름 줄에 "주 3회 중 2회 완료"를 읽어 준다.

**편집 시트 (`HabitEditorView`)**
- 섹션 제목 "반복 요일" → "반복".
- 맨 위에 세그먼트 `Picker`: `요일 정하기 | 주 n회`.
- 요일 정하기: 지금 화면 그대로(요일 버튼 + 요약 + "매일" 버튼).
- 주 n회: `Stepper`(1~6, 기본 3, 수정 시 기존 값) + 안내 "일주일에 3번, 아무 요일이나".
  "매일" 버튼은 숨긴다.
- 저장 조건: 이름이 있고, 요일 방식이면 요일 1개 이상. 주 n회면 요일 조건 없음.
- 저장: 주 n회면 `weeklyTarget = n`, 요일 방식이면 `nil`.

색은 `Theme` 토큰만 쓴다(다크 모드 대응).

## 샘플 데이터

`-seedSampleData`에 "명상 10분 · 주 3회" 습관을 추가하고, 지난 기록 생성 조건을
`isCheckable` 기준으로 바꿔 이 습관에도 체크가 생기게 한다. CI 스크린샷으로 표 표시를
확인한다.

## 테스트

`HabitProgressTests` (가짜 구조체에 `weeklyTarget` 추가):
- 주 n회 습관은 `isScheduled == false`, 만든 날 이후 모든 요일 `isCheckable == true`, 이전은 `false`
- 체크한 날만 `progress`에 들어간다(체크한 날 1/1, 안 한 날 0/0)
- 요일 습관과 섞였을 때 `progress` 합계
- `weeklyCount`: 같은 주만 센다, 일요일→월요일 경계에서 새로 센다, 만든 날 이전 기록 제외, 목표 초과도 센다
- `isWeeklyPending`: 목표 전 미완료 true, 그날 완료 false, 목표 달성 후 false
- `weeklySummary` 문자열

`ReminderPlannerTests`:
- 주 n회만 있을 때: 목표 전이면 이번 주 남은 날 모두 예약
- 이번 주 목표를 채웠으면 이번 주 남은 날 제외, 다음 주 월요일부터 다시 포함
- 오늘 이미 체크했으면 오늘 제외

## 바뀌는 파일

| 파일 | 변경 |
|---|---|
| `HabitTable/Habit.swift` | 프로토콜·모델에 `weeklyTarget` |
| `HabitTable/HabitProgress.swift` | 위 표의 규칙 |
| `HabitTable/ReminderPlanner.swift` | 대상 습관 조건 |
| `HabitTable/WeekMatrixView.swift` | 칸 상태, 이름 아래 횟수 |
| `HabitTable/HabitEditorView.swift` | 방식 전환, Stepper |
| `HabitTable/HabitBoardView.swift` | 재예약 키 |
| `HabitTable/HabitTableApp.swift` | 샘플 데이터 |
| `HabitTableTests/HabitProgressTests.swift`, `ReminderPlannerTests.swift` | 테스트 |
| `CLAUDE.md` | 규칙에 주 n회 설명 추가 |
