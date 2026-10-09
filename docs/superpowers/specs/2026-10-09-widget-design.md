# 홈 화면 위젯 설계

## 배경과 목적

앱을 열지 않고도 "오늘 할 습관이 남았는지"와 잔디를 보게 한다.
세 기능(주 n회 → 연속 기록 → **위젯**) 중 마지막이다. 계산은 `HabitProgress`를 그대로 쓴다.

## 요구사항 (사용자 확정, 2026-10-09)

- **작은 위젯 = 오늘 현황**: 오늘 달성 `done/total`과 남은 수.
- **중간 위젯 = 최근 4주 잔디**: 앱의 잔디(월요일 시작 7×4)와 평균 달성률.
- **보기만 한다.** 위젯을 누르면 앱의 습관 탭이 열린다. 위젯에서 체크하는 기능은 다음 단계로 미룬다.
- **확인은 앱 안 미리보기 스크린샷**: 실행 인자 `-widgetPreview`로 앱 안에 위젯 모양을 그려 CI가 찍는다.
  홈 화면에서 실제로 동작하는지는 이 방법으로 확인되지 않는다.
- 앱은 아직 실제 기기에 설치된 적이 없다(CI에서만 실행). 그래서 **기존 데이터를 옮기는 코드는 넣지 않는다.**

## 기획에서 정한 것

**작은 위젯 문구**
- 남은 습관 있음: "오늘" / `2/4` / "2개 남았어요"
- 모두 완료(`isDayComplete`, 하루 완성 효과와 같은 기준): "오늘" / `4/4` / "모두 해냈어요" + 꽃
- 오늘 셈에 들어갈 습관 없음(0/0): "오늘은 쉬는 날이에요"
- 습관이 하나도 없음: "습관을 추가해 보세요"

**중간 위젯**: "최근 4주 잔디" + 평균 `80%` + 7×4 칸(색 단계는 `HabitProgress.level`과 잔디 토큰 그대로,
미래 칸은 옅게). 날짜 숫자는 넣지 않는다(공간이 좁음). 오늘 칸은 테두리로 표시한다.

**갱신**
- 앱에서 습관이 바뀔 때(체크·추가·수정·삭제) `WidgetCenter.shared.reloadAllTimelines()`를 부른다.
  알림 재예약과 같은 곳(`HabitBoardView`의 `reminderSignature` 변경 시점)에 붙인다.
- 타임라인은 지금 항목 1개 + **다음 자정** 항목 1개, 정책 `.atEnd`. 날짜가 바뀌면 오늘 기준이 넘어간다.

**모양**
- 색은 `Theme` 토큰, 글꼴은 Spoqa(위젯 확장에도 글꼴 파일과 `FontRegistrar` 포함). 다크 모드 대응.
- iOS 17 규칙대로 `.containerBackground(Theme.meadow, for: .widget)`.
- 접근성: 작은 위젯 "오늘 4개 중 2개 완료, 2개 남았어요", 중간 위젯 "최근 4주 평균 80퍼센트".

## 구조

**데이터 공유**: 앱과 위젯이 같은 SwiftData 저장소를 쓰도록 App Group `group.com.habittable.app`
안에 저장한다. `ModelConfiguration(groupContainer: .identifier("group.com.habittable.app"))`.
위젯은 읽기만 한다. 저장소를 여는 코드는 한 곳(`SharedStore.makeContainer(inMemory:)`)에 모아
앱·위젯·미리보기가 같이 쓴다. 모델은 **Habit.self와 TodoItem.self 둘 다** 넣는다(CLAUDE.md 규칙).

**새 타깃** (`project.yml`): `HabitTableWidget` (type `app-extension`, WidgetKit). 앱과 공유하는 소스:
`Habit.swift`, `TodoItem.swift`, `HabitProgress.swift`, `Theme.swift`, `SharedStore.swift`, 글꼴 파일.
앱 타깃이 위젯을 포함(embed)한다. 앱·위젯에 App Group 권한 파일(entitlements)을 단다.

**계산 추가** (`HabitProgress`, 테스트 대상): 작은 위젯 문구를 고르는 순수 함수
`todaySummary(habits, today, calendar) -> TodaySummary`(완료·전체·상태: `.remaining(n)` / `.complete` /
`.rest` / `.noHabits`). 잔디는 기존 `lawnDates`, `progress`, `level`, `averagePercent`를 쓴다.

**미리보기**: `-widgetPreview -seedSampleData`로 실행하면 앱이 샘플 데이터로 작은·중간 위젯 뷰를
실제 크기(작은 158×158, 중간 338×158 — 기준 기기 기준)로 나란히 그린다. CI에 스크린샷
`widget-light.png`, `widget-dark.png`를 추가한다. 위젯 뷰 코드는 위젯 타깃과 앱 타깃이 공유한다.

## 가장 큰 위험과 순서

지금 빌드는 **서명 없이**(`CODE_SIGNING_ALLOWED: NO`) 한다. App Group은 권한 정보가 앱에 들어가야
동작하는데, 서명을 안 하면 이 정보가 빠져 시뮬레이터에서도 공유 저장소를 못 열 수 있다.
그래서 **맨 먼저 이것만 시험**한다.

1. **시험(spike)**: App Group 권한 파일을 달고, 단위 테스트 하나로
   `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`가 nil이 아닌지 CI에서 확인한다.
   실패하면 임시 서명(`CODE_SIGN_IDENTITY: "-"`, 시뮬레이터 전용)으로 다시 시험한다.
   둘 다 안 되면 여기서 멈추고 사용자와 다시 정한다.
2. 저장소를 `SharedStore`로 옮기기(앱 동작은 그대로, 기존 테스트·스크린샷 통과 확인).
3. 위젯 타깃과 두 위젯 화면, `todaySummary` + 테스트.
4. 미리보기 모드와 CI 스크린샷, 앱에서 갱신 호출.

## 범위 밖

위젯에서 체크, 잠금 화면 위젯, 큰 위젯, 할 일 위젯, 연속 기록 표시, 실제 기기 확인.

## 바뀌는 파일 (예상)

| 파일 | 변경 |
|---|---|
| `project.yml` | 위젯 타깃, App Group 권한, 공유 소스 |
| `HabitTable/SharedStore.swift` (새) | 저장소 열기 |
| `HabitTable/HabitTableApp.swift` | `SharedStore` 사용, `-widgetPreview` |
| `HabitTable/HabitProgress.swift` | `todaySummary` |
| `HabitTable/HabitBoardView.swift` | 위젯 갱신 호출 |
| `HabitTableWidget/*` (새) | 위젯 번들, 작은·중간 위젯 뷰, 타임라인 |
| `HabitTable/*.entitlements`, `HabitTableWidget/*.entitlements` (새) | App Group |
| `HabitTableTests/HabitProgressTests.swift` | `todaySummary` 테스트, App Group 시험 테스트 |
| `.github/workflows/ios.yml` | 위젯 미리보기 스크린샷 |
| `CLAUDE.md` | 구조·규칙 |
