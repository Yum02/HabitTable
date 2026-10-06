# 주 n회 목표 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 습관마다 "요일 정하기" 대신 "일주일에 n번, 아무 요일이나"를 고를 수 있게 한다.

**Architecture:** `Habit`에 선택형 `weeklyTarget: Int?` 하나를 더한다(nil = 요일 방식). 규칙은 순수 함수 `HabitProgress`에 모은다. `isScheduled`는 "그날 꼭 해야 하는 습관"으로 의미를 좁혀 주 n회는 항상 false로 둔다. 체크 칸 표시(`isCheckable`), 하루 달성률(`countsToward`), 이번 주 횟수(`weeklyCount`), 알림 대상(`isWeeklyPending`)은 새 함수로 나눈다. 화면은 표의 칸 상태와 이름 아래 횟수 표시, 편집 시트의 방식 전환만 바뀐다.

**Tech Stack:** Swift 5 · SwiftUI · SwiftData · XCTest · XcodeGen · GitHub Actions (로컬 빌드 불가)

**Spec:** `docs/superpowers/specs/2026-10-06-weekly-target-design.md`

## Global Constraints

- 최소 iOS 17, `SWIFT_VERSION: "5.0"`. 로컬에 Xcode가 없으므로 **컴파일 가능성을 손으로 꼼꼼히 확인**한다. 테스트·빌드는 push 후 GitHub Actions(`gh run watch`)로만 확인하며, **push는 사용자에게 먼저 확인한 뒤** 한다.
- UI 문구는 한국어 해요체. 색은 `Theme` 토큰만(다크 모드 대응), 글꼴은 `.font(.spoqa(크기, .굵기, relativeTo: .스타일))`.
- 날짜는 `DayKey`(정수), 달력은 `AppCalendar.make()`(월요일 시작). 주는 월~일.
- 계산 로직은 `HabitProgress`/`ReminderPlanner` 순수 함수로 두고, SwiftData 없이 `HabitSchedulable` 가짜 구조체로 테스트한다.
- SwiftData 변경은 `Habit.weeklyTarget: Int?` 추가 하나뿐이다(경량 마이그레이션, 마이그레이션 코드 없음).
- `weeklyTarget`은 nil 또는 1~6(`HabitProgress.weeklyTargetRange`). 새로 고를 때 기본 3.
- 2026-09-28은 **월요일**이다. 테스트 날짜는 이를 기준으로 쓴다.

## Review Focus

1. **연말을 걸친 주**(2026-12-28 월 ~ 2027-01-03 일)에서도 이번 주 횟수가 한 주로 이어져야 한다 → Task 1 `testWeeklyCountAcrossYearEnd`.
2. **주 중간에 만든 습관**은 만든 날 이전 기록(요일 방식이던 시절 기록 포함)을 이번 주 횟수에 넣지 않는다 → Task 1 `testWeeklyCountExcludesBeforeCreation`.
3. **같은 날짜가 `completedDays`에 두 번** 들어가 있어도 한 번만 센다 → Task 1 `testWeeklyCountIgnoresDuplicateKeys`.
4. **주 n회 습관만 있고 한 번도 안 한 주**는 잔디가 "할 습관 없음"이고 평균 달성률이 nil이다(0%로 떨어지지 않는다) → Task 1 `testWeeklyOnlyUncheckedWeekHasNoAverage`.
5. **일요일에 목표를 채우면** 다음 날(월요일)부터 알림이 다시 예약된다 → Task 2 `testWeeklyGoalMetOnSundayResumesOnMonday`.

---

### Task 1: 데이터와 계산 규칙

**Files:**
- Modify: `HabitTable/Habit.swift` (프로토콜, 모델, init)
- Modify: `HabitTable/HabitProgress.swift` (`isScheduled`, `progress`, 새 "주 n회" 섹션)
- Modify: `HabitTableTests/HabitProgressTests.swift` (가짜 구조체 + 새 테스트)
- Modify: `HabitTableTests/ReminderPlannerTests.swift:5-9` (가짜 구조체만 — 컴파일 유지용)

**Interfaces:**
- Produces:
  - `HabitSchedulable.weeklyTarget: Int? { get }`
  - `Habit.weeklyTarget: Int?`, `Habit.init(name:weekdays:createdDay:sortOrder:completedDays:weeklyTarget: Int? = nil)`
  - `HabitProgress.weeklyTargetRange: ClosedRange<Int>` (= `1...6`)
  - `HabitProgress.isCheckable<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool`
  - `HabitProgress.countsToward<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool`
  - `HabitProgress.weeklyCount<H: HabitSchedulable>(_ habit: H, weekContaining date: Date, calendar: Calendar) -> Int`
  - `HabitProgress.isWeeklyPending<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool`
  - `HabitProgress.weeklySummary(target: Int, count: Int) -> String`

- [ ] **Step 1: 가짜 구조체에 `weeklyTarget` 추가 (두 테스트 파일)**

`HabitTableTests/HabitProgressTests.swift`의 `TestHabit`:

```swift
private struct TestHabit: HabitSchedulable {
    var weekdays: [Int]
    var createdDay: Int
    var completedDays: [Int] = []
    var weeklyTarget: Int? = nil
}
```

`HabitTableTests/ReminderPlannerTests.swift`의 `ReminderTestHabit`도 똑같이 마지막 줄에 `var weeklyTarget: Int? = nil`을 더한다. 맨 끝에 기본값과 함께 두므로 기존 `TestHabit(weekdays:createdDay:completedDays:)` 호출은 그대로 컴파일된다.

- [ ] **Step 2: 실패하는 테스트 작성**

`HabitProgressTests.swift`의 마지막 `}` 바로 앞(`testWeekdaySummary` 뒤)에 추가:

```swift
    // MARK: - 주 n회

    private func weekly(_ target: Int, created: Int = 20260901, done: [Int] = []) -> TestHabit {
        TestHabit(weekdays: [], createdDay: created, completedDays: done, weeklyTarget: target)
    }

    func testWeeklyHabitIsNeverScheduledButCheckableAfterCreation() {
        let habit = weekly(3, created: 20260930)   // 9/30(수)에 만듦
        for d in 28...30 {
            XCTAssertFalse(HabitProgress.isScheduled(habit, on: date(2026, 9, d), calendar: cal), "9/\(d)")
        }
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 28), calendar: cal))
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 29), calendar: cal))
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 9, 30), calendar: cal))
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 10, 4), calendar: cal), "일요일도 체크 칸")
    }

    func testWeekdayHabitCheckableMatchesScheduled() {
        let habit = TestHabit(weekdays: [2, 4, 6], createdDay: 20260901)   // 월·수·금
        XCTAssertTrue(HabitProgress.isCheckable(habit, on: date(2026, 9, 28), calendar: cal))
        XCTAssertFalse(HabitProgress.isCheckable(habit, on: date(2026, 9, 29), calendar: cal))
    }

    func testWeeklyHabitCountsOnlyOnCheckedDays() {
        let habit = weekly(3, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 1, total: 1))
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 30), calendar: cal), DayProgress(done: 0, total: 0))
    }

    func testWeeklyMixedWithWeekdayHabit() {
        let daily = TestHabit(weekdays: Array(1...7), createdDay: 20260901)
        let habit = weekly(3, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([daily, habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 1, total: 2))
        XCTAssertEqual(HabitProgress.progress([daily, habit], on: date(2026, 9, 30), calendar: cal), DayProgress(done: 0, total: 1))
    }

    func testWeeklyCheckBeforeCreationDoesNotCount() {
        let habit = weekly(3, created: 20261001, done: [20260929])
        XCTAssertEqual(HabitProgress.progress([habit], on: date(2026, 9, 29), calendar: cal), DayProgress(done: 0, total: 0))
    }

    func testWeeklyOnlyUncheckedWeekHasNoAverage() {
        let habit = weekly(3)
        let week = HabitProgress.weekDates(containing: date(2026, 9, 30), calendar: cal)
        XCTAssertNil(HabitProgress.averagePercent([habit], dates: week, today: date(2026, 10, 4), calendar: cal))
        let p = HabitProgress.progress([habit], on: date(2026, 9, 30), calendar: cal)
        XCTAssertEqual(HabitProgress.level(for: p, date: date(2026, 9, 30), today: date(2026, 10, 4), calendar: cal), .none)
    }

    func testWeeklyCountOnlyThatWeek() {
        // 9/27(일)은 지난주, 10/5(월)는 다음 주
        let habit = weekly(3, done: [20260927, 20260928, 20260930, 20261004, 20261005])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 1), calendar: cal), 3)
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 4), calendar: cal), 3, "일요일은 같은 주")
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 5), calendar: cal), 1, "월요일부터 새로 센다")
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 27), calendar: cal), 1)
    }

    func testWeeklyCountExcludesBeforeCreation() {
        let habit = weekly(3, created: 20260930, done: [20260928, 20260930])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 10, 1), calendar: cal), 1)
    }

    func testWeeklyCountAllowsOverTarget() {
        let habit = weekly(2, done: [20260928, 20260929, 20260930])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 28), calendar: cal), 3)
    }

    func testWeeklyCountIgnoresDuplicateKeys() {
        let habit = weekly(3, done: [20260928, 20260928])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 9, 28), calendar: cal), 1)
    }

    func testWeeklyCountAcrossYearEnd() {
        // 2026-12-28(월) ~ 2027-01-03(일)이 한 주
        let habit = weekly(3, done: [20261228, 20270103, 20270104])
        XCTAssertEqual(HabitProgress.weeklyCount(habit, weekContaining: date(2026, 12, 31), calendar: cal), 2)
    }

    func testIsWeeklyPending() {
        let once = weekly(2, done: [20260928])
        XCTAssertFalse(HabitProgress.isWeeklyPending(once, on: date(2026, 9, 28), calendar: cal), "그날 이미 완료")
        XCTAssertTrue(HabitProgress.isWeeklyPending(once, on: date(2026, 9, 29), calendar: cal), "목표 전")

        let met = weekly(2, done: [20260928, 20260929])
        XCTAssertFalse(HabitProgress.isWeeklyPending(met, on: date(2026, 9, 30), calendar: cal), "목표 달성")
        XCTAssertTrue(HabitProgress.isWeeklyPending(met, on: date(2026, 10, 5), calendar: cal), "다음 주는 새로")

        let notYet = weekly(2, created: 20261001)
        XCTAssertFalse(HabitProgress.isWeeklyPending(notYet, on: date(2026, 9, 30), calendar: cal), "만들기 전")

        let weekday = TestHabit(weekdays: Array(1...7), createdDay: 20260901)
        XCTAssertFalse(HabitProgress.isWeeklyPending(weekday, on: date(2026, 9, 30), calendar: cal), "요일 습관은 해당 없음")
    }

    func testWeeklySummary() {
        XCTAssertEqual(HabitProgress.weeklySummary(target: 3, count: 2), "주 3회 · 2/3")
        XCTAssertEqual(HabitProgress.weeklySummary(target: 2, count: 4), "주 2회 · 4/2")
    }
```

- [ ] **Step 3: 프로토콜과 모델 수정 (`HabitTable/Habit.swift`)**

프로토콜의 `completedDays` 아래에 추가:

```swift
    /// nil이면 요일 방식, 1~6이면 "일주일에 n번, 아무 요일이나"
    var weeklyTarget: Int? { get }
```

`Habit` 모델을 다음으로 바꾼다:

```swift
@Model
final class Habit {
    var name: String
    var weekdays: [Int]
    var createdDay: Int
    var sortOrder: Int
    var completedDays: [Int]
    /// nil이면 요일 방식. 선택형이라 기존 데이터는 자동으로 nil이 된다.
    var weeklyTarget: Int? = nil

    init(name: String, weekdays: [Int], createdDay: Int, sortOrder: Int = 0,
         completedDays: [Int] = [], weeklyTarget: Int? = nil) {
        self.name = name
        self.weekdays = weekdays.sorted()
        self.createdDay = createdDay
        self.sortOrder = sortOrder
        self.completedDays = completedDays
        self.weeklyTarget = weeklyTarget
    }
}
```

- [ ] **Step 4: 규칙 구현 (`HabitTable/HabitProgress.swift`)**

`isScheduled`를 다음으로 바꾼다(주 n회는 항상 false):

```swift
    /// 그날 꼭 해야 하는 습관인가: 요일 방식이고, 요일이 맞고, 만든 날 이후.
    /// 주 n회 습관은 정해진 요일이 없으므로 항상 false (isCheckable·countsToward 참고)
    static func isScheduled<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard habit.weeklyTarget == nil,
              DayKey.make(date, calendar: calendar) >= habit.createdDay else { return false }
        return habit.weekdays.contains(calendar.component(.weekday, from: date))
    }
```

`progress`를 다음으로 바꾼다:

```swift
    /// 그날 달성률에 들어가는 습관 중 완료한 수
    static func progress<H: HabitSchedulable>(_ habits: [H], on date: Date, calendar: Calendar) -> DayProgress {
        let counted = habits.filter { countsToward($0, on: date, calendar: calendar) }
        let done = counted.filter { isCompleted($0, on: date, calendar: calendar) }.count
        return DayProgress(done: done, total: counted.count)
    }
```

`// MARK: - 색 단계` 바로 앞에 새 섹션을 넣는다:

```swift
    // MARK: - 주 n회

    static let weeklyTargetRange = 1...6

    /// 표에 체크 칸을 보여 줄 날인가: 만든 날 이후이고, 주 n회이거나 요일이 맞는다
    static func isCheckable<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard DayKey.make(date, calendar: calendar) >= habit.createdDay else { return false }
        return habit.weeklyTarget != nil || habit.weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// 하루 달성률에 넣는가: 그날 해야 하는 요일 습관이거나, 그날 체크한 주 n회 습관
    static func countsToward<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard habit.weeklyTarget != nil else { return isScheduled(habit, on: date, calendar: calendar) }
        return DayKey.make(date, calendar: calendar) >= habit.createdDay
            && isCompleted(habit, on: date, calendar: calendar)
    }

    /// date가 속한 월~일 주에 완료한 날 수. 만든 날 이전 기록과 중복 날짜는 세지 않는다.
    static func weeklyCount<H: HabitSchedulable>(_ habit: H, weekContaining date: Date, calendar: Calendar) -> Int {
        let week = weekDates(containing: date, calendar: calendar)
        guard let first = week.first, let last = week.last else { return 0 }
        let from = max(DayKey.make(first, calendar: calendar), habit.createdDay)
        let to = DayKey.make(last, calendar: calendar)
        return Set(habit.completedDays).filter { $0 >= from && $0 <= to }.count
    }

    /// 알림 대상인 주 n회 습관인가: 만든 날 이후, 그날 미완료, 그 주 목표 미달
    static func isWeeklyPending<H: HabitSchedulable>(_ habit: H, on date: Date, calendar: Calendar) -> Bool {
        guard let target = habit.weeklyTarget,
              DayKey.make(date, calendar: calendar) >= habit.createdDay,
              !isCompleted(habit, on: date, calendar: calendar) else { return false }
        return weeklyCount(habit, weekContaining: date, calendar: calendar) < target
    }

    /// "주 3회 · 2/3"
    static func weeklySummary(target: Int, count: Int) -> String {
        "주 \(target)회 · \(count)/\(target)"
    }
```

DayKey는 연·월·일 순 정수라 크기 비교가 날짜 순서와 같다(연말 경계 포함).

- [ ] **Step 5: 컴파일 손 점검**

다음을 직접 확인한다.
- `Habit`이 `HabitSchedulable`의 `weeklyTarget`을 만족하는지.
- `HabitTableApp.swift`, `HabitEditorView.swift`의 기존 `Habit(...)` 호출이 새 기본값 덕분에 그대로 컴파일되는지.
- 테스트의 `DayProgress`가 `Equatable`인지(이미 그렇다).

- [ ] **Step 6: Commit**

```bash
git add HabitTable/Habit.swift HabitTable/HabitProgress.swift HabitTableTests/HabitProgressTests.swift HabitTableTests/ReminderPlannerTests.swift
git commit -m "주 n회 목표 데이터와 계산 규칙 추가, 테스트 보강"
```

---

### Task 2: 알림 대상 조건

**Files:**
- Modify: `HabitTable/ReminderPlanner.swift:9-27` (`plannedDays`)
- Modify: `HabitTable/HabitBoardView.swift:31-33` (`reminderSignature`)
- Test: `HabitTableTests/ReminderPlannerTests.swift`

**Interfaces:**
- Consumes: `HabitProgress.isScheduled`, `HabitProgress.isWeeklyPending`, `HabitProgress.isCompleted` (Task 1), `ReminderTestHabit.weeklyTarget` (Task 1 Step 1)
- Produces: `ReminderPlanner.plannedDays` 시그니처는 그대로. 동작만 주 n회 반영.

- [ ] **Step 1: 실패하는 테스트 작성**

`ReminderPlannerTests.swift`의 `// MARK: - 시각 변환` 바로 앞(같은 클래스 안, 해당 MARK가 없다면 `testMinutesFromDate` 앞)에 추가:

```swift
    // MARK: - 주 n회

    private func weekly(_ target: Int, done: [Int] = []) -> ReminderTestHabit {
        ReminderTestHabit(weekdays: [], createdDay: 20260901, completedDays: done, weeklyTarget: target)
    }

    func testWeeklyBeforeGoalPlansEveryDay() {
        let expected = [20260928, 20260929, 20260930] + Array(20261001...20261011)
        XCTAssertEqual(planned([weekly(3)], now: at(2026, 9, 28)), expected)
    }

    func testWeeklyGoalMetSkipsRestOfWeek() {
        // 9/28(월)·9/29(화)에 2회 → 목표 달성. 9/29 아침 기준: 이번 주 남은 날은 빼고 10/5(월)부터
        let habit = weekly(2, done: [20260928, 20260929])
        XCTAssertEqual(planned([habit], now: at(2026, 9, 29)), Array(20261005...20261012))
    }

    func testWeeklyCheckedTodaySkipsTodayOnly() {
        let habit = weekly(3, done: [20260928])
        let expected = [20260929, 20260930] + Array(20261001...20261011)
        XCTAssertEqual(planned([habit], now: at(2026, 9, 28)), expected)
    }

    func testWeeklyGoalMetOnSundayResumesOnMonday() {
        // 10/4(일)에 목표 1회 달성 → 10/5(월)부터 다시
        let habit = weekly(1, done: [20261004])
        XCTAssertEqual(planned([habit], now: at(2026, 10, 4)), Array(20261005...20261017))
    }

    func testWeeklyGoalMetButWeekdayHabitStillPlans() {
        let wednesdayOnly = ReminderTestHabit(weekdays: [4], createdDay: 20260901)   // 수
        let met = weekly(1, done: [20260929])
        // 9/29 아침: 주 n회는 이번 주 목표 달성 → 9/30(수)은 요일 습관 때문에만 들어간다
        XCTAssertEqual(planned([wednesdayOnly, met], now: at(2026, 9, 29)),
                       [20260930] + Array(20261005...20261012))
    }
```

(마지막 테스트: 9/29는 둘 다 대상이 아니다(수요일 아님, 주 n회는 그날 완료). 10/1~10/4도 대상이 없다. 10/5부터는 주 n회가 다시 대상이라 매일 들어간다.)

- [ ] **Step 2: 구현 (`ReminderPlanner.plannedDays`)**

함수 설명 주석과 루프 본문을 다음으로 바꾼다:

```swift
    /// 오늘부터 `days`일 중 알림을 예약할 날짜(DayKey). 오름차순.
    /// - 그날 대상 습관(해야 하는 요일 습관, 또는 그 주 목표 전인 주 n회 습관)이 없으면 제외한다.
    /// - 오늘은 알림 시각이 아직 미래이고, 대상 중 체크 안 한 게 있을 때만 포함한다.
    static func plannedDays<H: HabitSchedulable>(
        habits: [H], now: Date, hour: Int, minute: Int,
        days: Int = 14, calendar: Calendar
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        var result: [Int] = []
        for offset in 0..<max(days, 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let targets = habits.filter {
                HabitProgress.isScheduled($0, on: day, calendar: calendar)
                    || HabitProgress.isWeeklyPending($0, on: day, calendar: calendar)
            }
            guard !targets.isEmpty else { continue }
            if offset == 0 {
                guard let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      fire > now,
                      targets.contains(where: { !HabitProgress.isCompleted($0, on: day, calendar: calendar) })
                else { continue }
            }
            result.append(DayKey.make(day, calendar: calendar))
        }
        return result
    }
```

- [ ] **Step 3: 재예약 지문에 `weeklyTarget` 추가 (`HabitBoardView.swift`)**

```swift
    private var reminderSignature: [String] {
        habits.map { "\($0.createdDay)|\($0.weekdays)|\($0.weeklyTarget ?? 0)|\($0.completedDays)" }
    }
```

- [ ] **Step 4: 컴파일 손 점검**

다음을 직접 확인한다.
- `targets` 이름이 함수 안의 다른 이름과 겹치지 않는지.
- 기존 테스트 `testHabitWithNoWeekdaysPlansNothing`(요일 [] + weeklyTarget nil)이 여전히 `[]`인지. `isScheduled`는 false이고 `isWeeklyPending`도 false라서 그대로 `[]`예요.

- [ ] **Step 5: Commit**

```bash
git add HabitTable/ReminderPlanner.swift HabitTable/HabitBoardView.swift HabitTableTests/ReminderPlannerTests.swift
git commit -m "알림 예약에 주 n회 목표 반영"
```

---

### Task 3: 이번 주 표

**Files:**
- Modify: `HabitTable/WeekMatrixView.swift` (이름 칸, `state(of:on:)`, `accessibilityLabel`, 새 `WeeklyBadge`)

**Interfaces:**
- Consumes: `HabitProgress.isCheckable`, `HabitProgress.weeklyCount`, `HabitProgress.weeklySummary`, `Habit.weeklyTarget` (Task 1)
- Produces: 없음 (화면)

- [ ] **Step 1: 칸 상태를 `isCheckable` 기준으로**

```swift
    private func state(of habit: Habit, on date: Date) -> CheckCell.CellState {
        guard HabitProgress.isCheckable(habit, on: date, calendar: calendar) else { return .rest }
        guard HabitProgress.canToggle(date: date, today: today, calendar: calendar) else { return .future }
        return HabitProgress.isCompleted(habit, on: date, calendar: calendar) ? .done : .missed
    }
```

- [ ] **Step 2: 이름 칸에 횟수 표시**

`ForEach(habits)` 안의 `Text(habit.name) … .accessibilityHint(…)` 블록 전체를 다음으로 바꾼다:

```swift
                    VStack(alignment: .leading, spacing: 1) {
                        Text(habit.name)
                            .font(.spoqa(12.5, .bold, relativeTo: .subheadline))
                            .foregroundStyle(Theme.soil)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let target = habit.weeklyTarget {
                            WeeklyBadge(target: target, count: weeklyCount(of: habit))
                        }
                    }
                    .frame(width: nameWidth, height: 34, alignment: .leading)
                    .padding(.leading, 4)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button { onEdit(habit) } label: { Label("수정", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(habit) } label: { Label("삭제", systemImage: "trash") }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(nameAccessibilityLabel(habit))
                    .accessibilityHint("길게 누르면 수정하거나 삭제할 수 있어요")
```

`state(of:on:)` 아래에 도우미 두 개를 추가한다. `week`는 지금 보고 있는 주(‹ ›로 넘긴 주 포함)다.

```swift
    /// 지금 보고 있는 주의 횟수
    private func weeklyCount(of habit: Habit) -> Int {
        HabitProgress.weeklyCount(habit, weekContaining: week.first ?? today, calendar: calendar)
    }

    private func nameAccessibilityLabel(_ habit: Habit) -> String {
        guard let target = habit.weeklyTarget else { return habit.name }
        return "\(habit.name), 주 \(target)회 중 \(weeklyCount(of: habit))회 완료"
    }
```

- [ ] **Step 3: `WeeklyBadge` 추가**

파일 끝(`CheckCell` 아래)에 추가:

```swift
/// 주 n회 습관의 그 주 횟수 (예: 주 3회 · 2/3). 목표를 채우면 진한 초록 + ✓
private struct WeeklyBadge: View {
    let target: Int
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Text(HabitProgress.weeklySummary(target: target, count: count))
                .monospacedDigit()
            if count >= target {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
            }
        }
        .font(.spoqa(10, .medium, relativeTo: .caption2))
        .foregroundStyle(count >= target ? Theme.grass4 : Theme.stem)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
```

- [ ] **Step 4: 컴파일 손 점검**

다음을 직접 확인한다.
- `Theme.grass4`와 `Theme.stem`이 있는지(있다).
- `.font(.spoqa(10, .medium, relativeTo: .caption2))` 형식이 `Theme.swift`의 `Font.spoqa` 시그니처와 맞는지. `.medium` 굵기가 있는지 `Theme.swift`에서 확인한다. 편집 시트에서 이미 `.medium`을 쓰고 있다.
- `GridRow` 안의 첫 칸이 하나의 뷰(VStack)인지.

- [ ] **Step 5: Commit**

```bash
git add HabitTable/WeekMatrixView.swift
git commit -m "이번 주 표에 주 n회 체크 칸과 횟수 표시 추가"
```

---

### Task 4: 편집 시트

**Files:**
- Modify: `HabitTable/HabitEditorView.swift` (상태, init, `canSave`, "반복" 섹션, `save()`)

**Interfaces:**
- Consumes: `Habit.weeklyTarget`, `Habit.init(...weeklyTarget:)`, `HabitProgress.weeklyTargetRange` (Task 1)
- Produces: 없음 (화면)

- [ ] **Step 1: 상태와 init**

`@State private var weekdays: Set<Int>` 아래에 추가:

```swift
    @State private var isWeekly: Bool
    @State private var weeklyTarget: Int
```

`init` 끝에 추가(범위 밖 값은 1~6으로 맞춘다):

```swift
        _isWeekly = State(initialValue: habit?.weeklyTarget != nil)
        let range = HabitProgress.weeklyTargetRange
        _weeklyTarget = State(initialValue: min(max(habit?.weeklyTarget ?? 3, range.lowerBound), range.upperBound))
```

- [ ] **Step 2: 저장 조건**

```swift
    private var canSave: Bool {
        !trimmedName.isEmpty && (isWeekly || !weekdays.isEmpty)
    }
```

- [ ] **Step 3: "반복" 섹션**

`section(title: "반복 요일", …) { … }` 전체를 다음으로 바꾼다:

```swift
                    section(title: "반복", trailing: {
                        if !isWeekly {
                            Button("매일") { weekdays = Set(1...7) }
                                .font(.spoqa(13, .bold, relativeTo: .footnote))
                                .foregroundStyle(Theme.grass4)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("반복 방식", selection: $isWeekly) {
                                Text("요일 정하기").tag(false)
                                Text("주 n회").tag(true)
                            }
                            .pickerStyle(.segmented)

                            if isWeekly {
                                Stepper(value: $weeklyTarget, in: HabitProgress.weeklyTargetRange) {
                                    Text("주 \(weeklyTarget)회")
                                        .font(.spoqa(17, .bold, relativeTo: .body))
                                        .foregroundStyle(Theme.soil)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                                Text("일주일에 \(weeklyTarget)번, 아무 요일이나")
                                    .font(.spoqa(13, .medium, relativeTo: .footnote))
                                    .foregroundStyle(Theme.stem)
                                    .padding(.leading, 4)
                            } else {
                                WeekdayPicker(selection: $weekdays)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                                Text(weekdays.isEmpty ? "요일을 하나 이상 골라 주세요" : HabitProgress.weekdaySummary(Array(weekdays)))
                                    .font(.spoqa(13, .medium, relativeTo: .footnote))
                                    .foregroundStyle(weekdays.isEmpty ? Theme.sunday : Theme.stem)
                                    .padding(.leading, 4)
                            }
                        }
                    }
```

`trailing`은 `@ViewBuilder`라 `if`만 있어도 컴파일된다(Optional 뷰).

- [ ] **Step 4: 저장**

```swift
    private func save() {
        guard canSave else { return }
        let days = weekdays.sorted()
        let target: Int? = isWeekly ? weeklyTarget : nil
        if let habit {
            habit.name = trimmedName
            habit.weekdays = days
            habit.weeklyTarget = target
        } else {
            context.insert(Habit(
                name: trimmedName,
                weekdays: days,
                createdDay: DayKey.make(.now, calendar: calendar),
                sortOrder: nextSortOrder,
                weeklyTarget: target
            ))
        }
        dismiss()
    }
```

주 n회일 때도 `weekdays`는 고른 값 그대로 저장한다(요일 방식으로 되돌릴 때 이전 선택이 남는다). 체크 기록은 건드리지 않는다.

- [ ] **Step 5: 컴파일 손 점검**

다음을 직접 확인한다.
- `Stepper(value:in:label:)`의 `in:`에 `ClosedRange<Int>`가 들어가는지.
- `Picker` 선택값 `Bool`과 `.tag(false/true)`의 타입이 같은지.
- `Theme.sunday`가 그대로 있는지.

- [ ] **Step 6: Commit**

```bash
git add HabitTable/HabitEditorView.swift
git commit -m "습관 편집 시트에 요일 정하기/주 n회 전환 추가"
```

---

### Task 5: 샘플 데이터, 문서, CI 확인

**Files:**
- Modify: `HabitTable/HabitTableApp.swift` (`SampleData.insert`)
- Modify: `CLAUDE.md` (규칙)

**Interfaces:**
- Consumes: `Habit.init(...weeklyTarget:)`, `HabitProgress.isCheckable` (Task 1)

- [ ] **Step 1: 샘플 습관 추가와 기록 조건 변경**

`habits` 배열에 네 번째 습관 추가:

```swift
            Habit(name: "명상 10분", weekdays: Array(1...7), createdDay: startKey, sortOrder: 3, weeklyTarget: 3),
```

지난 기록 루프의 `where` 조건을 바꾼다. 요일 습관은 `isCheckable == isScheduled`라서 기존 모양이 그대로이고, 주 n회는 3일에 한 번(주 2~3회) 체크된다.

```swift
            for (index, habit) in habits.enumerated()
            where HabitProgress.isCheckable(habit, on: day, calendar: cal)
                && (habit.weeklyTarget == nil ? (offset * 7 + index * 3) % 5 != 0 : offset % 3 == 0) {
                habit.completedDays.append(key)
            }
```

- [ ] **Step 2: CLAUDE.md 규칙 추가**

"## 규칙"의 `- 체크는 오늘까지만 가능, 습관은 \`createdDay\` 이후만 계산.` 아래에 추가:

```markdown
- 습관은 요일 방식(`weeklyTarget == nil`) 또는 주 n회(`weeklyTarget` 1~6, 월~일 기준). 주 n회는 `isScheduled`가 항상 false이고, 체크 칸은 `isCheckable`, 하루 달성률은 체크한 날만(`countsToward`), 알림은 그 주 목표 전·그날 미완료일 때(`isWeeklyPending`).
```

- [ ] **Step 3: Commit**

```bash
git add HabitTable/HabitTableApp.swift CLAUDE.md
git commit -m "샘플 데이터에 주 n회 습관 추가, 규칙 문서화"
```

- [ ] **Step 4: push 전에 사용자 확인 → push → CI 확인**

사용자에게 push 여부를 묻는다. 승인을 받으면 진행한다:

```bash
git push -u origin feature/weekly-target
gh run watch
```

기대 결과: 단위 테스트가 모두 통과한다(기존 테스트 + 새 테스트). 실패하면 `gh run view --log-failed`로 확인한다.

- [ ] **Step 5: 스크린샷 확인**

```bash
gh run download -n screenshots -D <스크래치 디렉터리>/screenshots
```

확인할 것:
- 습관 표 네 번째 줄 "명상 10분" 아래에 `주 3회 · n/3`이 보인다.
- 명상 줄에는 "–" 없이 오늘까지 체크 칸이 있고, 미래는 점선이다.
- 이름 칸 너비와 줄 높이가 기존 줄과 같다(글자가 잘리거나 겹치지 않는다).
