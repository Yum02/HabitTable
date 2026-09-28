# 습관 체크 알림 설계

## 배경과 목적

습관을 하루 안에 체크하는 걸 잊지 않도록, 정해 둔 시각에 로컬 알림을 보낸다.
할 일(To-do) 마감 알림은 이번 범위가 아니다(나중에 따로 설계).

## 요구사항 (사용자 확정)

- 알림 시각은 **하루 한 번, 전체 공통**이다. 습관별 시각은 없다.
- **그날 체크할 습관이 남아 있을 때만** 알림이 울린다. 오늘 습관을 다 체크하면
  오늘 알림은 취소되고, 체크를 풀면 다시 예약된다.
- 그날 할 습관이 하나도 없는 날(모두 쉬는 요일)에는 알림을 예약하지 않는다.
- 알림 켜기/끄기와 시각은 설정 시트에서 바꾼다.

## 제약

- 개발 환경에 Mac이 없어 알림 발송은 CI로 확인할 수 없다. 그래서 "어느 날에
  알림을 예약할지" 계산은 순수 함수로 만들어 테스트하고, 실제 발송은 얇은 래퍼로
  둔다.
- 로컬 알림은 앱이 꺼져 있으면 완료 여부를 알 수 없다. 그래서 앱이 켜질 때마다
  앞으로 14일치를 다시 예약하는 방식을 쓴다. 앱을 14일 넘게 열지 않으면 예약이
  끝난다(알려진 한계).

## 구조

| 파일 | 역할 |
|---|---|
| `HabitTable/ReminderPlanner.swift` | 순수 함수. 예약할 날짜 목록 계산 ← 테스트 대상 |
| `HabitTable/ReminderScheduler.swift` | `UNUserNotificationCenter` 얇은 래퍼: 권한 요청, 예약 전체 삭제 후 재예약 |
| `HabitTable/ReminderSettingsView.swift` | 설정 시트: 켜기/끄기 스위치 + 시각 선택 |
| `HabitTableTests/ReminderPlannerTests.swift` | 계획 규칙 단위 테스트 |

설정값(켜짐 여부, 시·분)은 `@AppStorage`에 저장한다. SwiftData 모델은 바꾸지
않는다.

## 계산 규칙 (`ReminderPlanner`)

```swift
enum ReminderPlanner {
    /// 앞으로 `days`일(오늘 포함) 중 알림을 예약할 날짜(DayKey) 목록. 오름차순.
    static func plannedDays<H: HabitSchedulable>(
        habits: [H], now: Date, hour: Int, minute: Int,
        days: Int = 14, calendar: Calendar
    ) -> [Int]
}
```

- 후보는 오늘부터 `days`일이다.
- 그날 `HabitProgress.isScheduled`인 습관이 없으면 제외한다(습관은 `createdDay`
  이후만 해당).
- **오늘**은 추가로 다음 두 조건을 모두 만족해야 포함한다.
  - 알림 시각(`hour:minute`)이 `now`보다 미래다.
  - 오늘 할 습관 중 체크하지 않은 것이 하나 이상 있다.
- 미래 날짜는 아직 체크된 게 없으므로 "할 습관이 있는가"만 본다.
- 날짜 계산은 `AppCalendar.make()`와 `DayKey`를 쓴다(월말·연말 경계 포함).

## 예약 (`ReminderScheduler`)

- 식별자는 `reminder-<DayKey>`(예: `reminder-20260928`).
- 재예약 = 기존 `reminder-` 접두사 예약을 모두 지우고 `plannedDays` 결과대로
  새로 추가한다. 알림이 꺼져 있으면 지우기만 한다.
- 알림 문구는 "오늘 체크할 습관이 남아 있어요"로 통일한다. 미래 날짜는 예약
  시점에 남은 개수를 알 수 없으므로 개수는 넣지 않는다. 제목은 "Habit Table".
- 발송 시각은 `UNCalendarNotificationTrigger`(연·월·일·시·분, 비반복)로 지정한다.

## 다시 예약하는 시점

- 앱이 활성화될 때(`scenePhase == .active`)
- 습관을 체크/해제할 때
- 습관을 추가·수정·삭제할 때
- 설정(켜기/끄기, 시각)을 바꿀 때

## 화면

- 습관 화면(`HabitBoardView`) 머리글에 종 모양 버튼을 추가하고, 누르면
  `ReminderSettingsView` 시트가 열린다.
- 스위치를 켤 때 처음 권한을 요청한다. 거부되면 스위치를 다시 끄고 "설정 앱에서
  알림을 허용해 주세요"를 안내한다.
- UI 문구는 해요체, 색은 `Theme` 토큰만 쓴다.

## 테스트 (`ReminderPlannerTests`)

가짜 `HabitSchedulable` 구조체로 SwiftData 없이 작성한다.

- 쉬는 요일만 있는 날은 제외된다.
- 습관이 없으면 빈 목록이다.
- 오늘 습관을 모두 체크했으면 오늘이 빠진다. 하나라도 남으면 포함된다.
- 오늘 알림 시각이 이미 지났으면 오늘이 빠지고 내일부터 시작한다.
- 알림 시각 정각(`now == 시각`)은 지난 것으로 본다(미래만 포함).
- `createdDay` 이전 날짜는 해당 습관이 계산되지 않는다.
- 월말·연말 경계(예: 12/31 → 1/1)에서 날짜가 이어진다.
- 결과는 오름차순이고 최대 `days`개다.

## 범위 밖

- 할 일 마감 알림, 습관별 시각, 알림 문구 개인화
- 14일 넘게 앱을 열지 않았을 때의 예약 유지(백그라운드 갱신)
- 알림 액션 버튼(알림에서 바로 체크)
