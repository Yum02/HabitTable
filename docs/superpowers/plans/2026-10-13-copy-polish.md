# 화면 문구 다듬기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2026-10-13 문구 점검에서 찾은 6곳(틀린 문구 1, 빠진 내용 1, 개발자 표기 1, 접근성 3)을 고친다.

**Architecture:** 조건에 따라 달라지는 문구와 접근성 문구는 순수 함수(`HabitProgress`, `TodoProgress`)로 옮겨 단위 테스트로 고정한다. 뷰는 그 함수를 부르기만 한다. 조건 없는 고정 문구 두 곳은 뷰에서 바로 바꾼다. 데이터 모델과 화면 배치는 바꾸지 않는다.

**Tech Stack:** Swift · SwiftUI · XCTest, iOS 17. 로컬 빌드 불가(Windows) — 검증은 push 후 GitHub Actions(`.github/workflows/ios.yml`)의 단위 테스트와 스크린샷.

**Spec:** 따로 설계 문서는 없다. 근거는 아래 "바꿀 문구 표"(2026-10-13 춘글이 점검, 사용자 요청으로 계획 작성)이다.

## 바꿀 문구 표

| # | 위치 | 지금 | 바꾼 뒤 |
|---|------|------|---------|
| 1 | `TodoListView.swift` 빈 화면, 지난 날짜 | "아래 버튼으로 이 날 할 일을 **미리** 적어 둘 수 있어요." (어제에도 나옴) | 지난 날: "아래 버튼으로 이 날 한 일을 적어 둘 수도 있어요." / 앞으로의 날: 지금 문구 그대로 / 오늘: 지금 문구 그대로 |
| 2 | `HabitBoardView.swift` 습관 빈 화면 설명 | "매일 또는 원하는 요일에 할 습관을 추가하면, …" | "매일, 원하는 요일, 또는 일주일에 몇 번 할 습관을 추가하면, 이번 주 표와 잔디가 채워지기 시작해요." |
| 3 | `HabitEditorView.swift` 반복 방식 버튼 | `요일 정하기 \| 주 n회` | `요일 정하기 \| 횟수 정하기` |
| 4 | `LawnView.swift` 잔디 칸 VoiceOver | "9일 절반 미만" (몇 월인지 없음) | "10월 9일, 절반 미만 달성" |
| 5 | `LawnView.swift` 잔디 단계 말 | 달성 0% / 절반 미만 / 절반 이상 / 대부분 달성 / 모두 달성 | 0% 달성 / 절반 미만 달성 / 절반 이상 달성 / 대부분 달성 / 모두 달성 (할 습관 없음·아직 안 온 날은 그대로) |
| 6 | `WeekMatrixView.swift` 주 n회 이름 VoiceOver | "주 3회 중 3회 완료" (목표를 채워도 같음) | 목표를 채우면 "주 3회 중 3회 완료, 목표 달성" |

**이번에 하지 않는 것** (사용자 결정 대기): 오늘 칸을 "미완료" 대신 "아직 안 함"으로 읽기, 알림 문장 바꾸기.

## Global Constraints

- UI 문구는 한국어 해요체. 위 표의 문구를 **글자 그대로** 쓴다(쉼표·띄어쓰기 포함).
- 날짜 비교는 `DayKey`(정수, 예: 20261013)로 한다.
- 색은 `Theme` 토큰만, 글꼴은 `.font(.spoqa(…))` — 이번 작업에서 스타일은 건드리지 않는다.
- 계산·문구 규칙은 순수 함수에 두고 테스트를 먼저 쓴다. 테스트는 SwiftData 없이 작성한다.
- 로컬에서 컴파일할 수 없으니 바꾼 Swift 코드는 타입·괄호·`return`을 특히 꼼꼼히 본다.
- `git add`는 이 계획이 말한 파일만. 작업 폴더에 있는 `graphify-out/`, `.vscode/` 변경은 커밋하지 않는다.
- 다른 창(다른 세션)이 같은 폴더를 쓰고 있으므로 **git worktree에서** 작업한다: `feature/weekly-target`에서 새 브랜치 `feature/copy-polish`를 만든다.

## Review Focus

1. **어제·내일 경계** — 어제는 "한 일을 적어 둘 수도", 내일은 "미리 적어 둘". 오늘만 첫 안내 문구. (Task 2 `testEmptyStateTodayFuturePast`)
2. **연말을 넘는 날짜** — 오늘 12/31에 1/1을 보면 앞으로의 날, 1/1에 12/31을 보면 지난 날. DayKey 정수 비교가 맞는지. (Task 2 `testEmptyStateAcrossYearEnd`)
3. **목표를 넘긴 주** (주 2회인데 4회) — 화면 ✓와 똑같이 "목표 달성"을 읽어야 한다(둘 다 `count >= target`). (Task 1 `testWeeklySpoken`)
4. **잔디 4주가 달을 넘을 때** — 9/30과 10/1 칸이 각자 자기 달로 읽혀야 한다. (Task 1 `testLawnCellSpokenUsesOwnMonth`)
5. **0회인 주 n회 습관** — "주 3회 중 0회 완료"로 읽고 "목표 달성"은 붙지 않는다. (Task 1 `testWeeklySpoken`)

---

### Task 1: 접근성 문구 함수 (주 n회 목표 달성, 잔디 칸)

**Files:**
- Modify: `HabitTable/HabitProgress.swift` (함수 2개 추가)
- Modify: `HabitTable/WeekMatrixView.swift:109` (주 n회 접근성 문구)
- Modify: `HabitTable/LawnView.swift` (`LawnCell`에 접근성 문구 넘기기, `levelDescription` 삭제)
- Test: `HabitTableTests/HabitProgressTests.swift`

**Interfaces:**
- Consumes: `ProgressLevel`(같은 파일), `HabitProgress.level(for:date:today:calendar:)`
- Produces:
  - `static func weeklySpoken(target: Int, count: Int) -> String`
  - `static func lawnCellSpoken(date: Date, level: ProgressLevel, calendar: Calendar) -> String`

- [ ] **Step 1: 실패하는 테스트 쓰기**

`HabitProgressTests.swift`의 `testWeeklySummary()` 바로 아래에 추가:

```swift
    func testWeeklySpoken() {
        XCTAssertEqual(HabitProgress.weeklySpoken(target: 3, count: 0), "주 3회 중 0회 완료")
        XCTAssertEqual(HabitProgress.weeklySpoken(target: 3, count: 2), "주 3회 중 2회 완료")
        XCTAssertEqual(HabitProgress.weeklySpoken(target: 3, count: 3), "주 3회 중 3회 완료, 목표 달성")
        XCTAssertEqual(HabitProgress.weeklySpoken(target: 2, count: 4), "주 2회 중 4회 완료, 목표 달성")
    }
```

`testLevels()` 바로 아래에 추가:

```swift
    func testLawnCellSpokenLevels() {
        let d = date(2026, 10, 9)
        func spoken(_ level: ProgressLevel) -> String {
            HabitProgress.lawnCellSpoken(date: d, level: level, calendar: cal)
        }
        XCTAssertEqual(spoken(.none), "10월 9일, 할 습관 없음")
        XCTAssertEqual(spoken(.zero), "10월 9일, 0% 달성")
        XCTAssertEqual(spoken(.low), "10월 9일, 절반 미만 달성")
        XCTAssertEqual(spoken(.mid), "10월 9일, 절반 이상 달성")
        XCTAssertEqual(spoken(.high), "10월 9일, 대부분 달성")
        XCTAssertEqual(spoken(.full), "10월 9일, 모두 달성")
        XCTAssertEqual(spoken(.future), "10월 9일, 아직 안 온 날")
    }

    /// 4주 잔디가 달을 넘으면 칸마다 자기 달로 읽는다
    func testLawnCellSpokenUsesOwnMonth() {
        XCTAssertEqual(HabitProgress.lawnCellSpoken(date: date(2026, 9, 30), level: .full, calendar: cal), "9월 30일, 모두 달성")
        XCTAssertEqual(HabitProgress.lawnCellSpoken(date: date(2026, 10, 1), level: .full, calendar: cal), "10월 1일, 모두 달성")
        XCTAssertEqual(HabitProgress.lawnCellSpoken(date: date(2027, 1, 1), level: .zero, calendar: cal), "1월 1일, 0% 달성")
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

로컬 실행 불가. 함수가 없으므로 컴파일 오류가 나야 정상이다(`type 'HabitProgress' has no member 'weeklySpoken'`). push는 Task 3 끝에 한 번에 하므로 여기서는 테스트 이름과 기대 문구가 표와 같은지 눈으로 확인한다.

- [ ] **Step 3: 함수 구현**

`HabitProgress.swift`의 `weeklySummary` 바로 아래에 추가:

```swift
    /// 접근성용 "주 3회 중 2회 완료". 목표를 채우면(화면의 ✓와 같은 조건) ", 목표 달성"을 붙인다.
    static func weeklySpoken(target: Int, count: Int) -> String {
        let base = "주 \(target)회 중 \(count)회 완료"
        return count >= target ? base + ", 목표 달성" : base
    }
```

`HabitProgress.swift`의 `level(for:date:today:calendar:)` 바로 아래에 추가:

```swift
    /// 잔디 칸 접근성: "10월 9일, 절반 미만 달성". 4주가 달을 넘을 수 있어 월을 함께 읽는다.
    static func lawnCellSpoken(date: Date, level: ProgressLevel, calendar: Calendar) -> String {
        let monthDay = "\(calendar.component(.month, from: date))월 \(calendar.component(.day, from: date))일"
        let status: String
        switch level {
        case .none: status = "할 습관 없음"
        case .zero: status = "0% 달성"
        case .low: status = "절반 미만 달성"
        case .mid: status = "절반 이상 달성"
        case .high: status = "대부분 달성"
        case .full: status = "모두 달성"
        case .future: status = "아직 안 온 날"
        }
        return "\(monthDay), \(status)"
    }
```

- [ ] **Step 4: 뷰에 연결**

`WeekMatrixView.swift` `nameAccessibilityLabel`에서:

```swift
            parts.append("주 \(target)회 중 \(weeklyCount(of: habit))회 완료")
```
를
```swift
            parts.append(HabitProgress.weeklySpoken(target: target, count: weeklyCount(of: habit)))
```
로 바꾼다.

`LawnView.swift`:

1) `LawnView.body`의 `ForEach(dates…)` 안을 다음으로 바꾼다(레벨을 한 번만 계산):

```swift
                ForEach(dates, id: \.self) { date in
                    let cellLevel = level(on: date)
                    LawnCell(
                        day: calendar.component(.day, from: date),
                        level: cellLevel,
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        spokenLabel: HabitProgress.lawnCellSpoken(date: date, level: cellLevel, calendar: calendar)
                    )
                }
```

2) `LawnCell`에 속성 추가(`let isToday: Bool` 아래):

```swift
    let spokenLabel: String
```

3) `LawnCell.body` 끝의
```swift
        .accessibilityLabel("\(day)일 \(levelDescription)")
```
를
```swift
        .accessibilityLabel(spokenLabel)
```
로 바꾸고, `private var levelDescription: String { … }` 전체를 지운다.

컴파일 확인: `ForEach` 클로저 안의 `let`은 iOS 17 `@ViewBuilder`에서 허용된다. `LawnCell`은 멤버와이즈 init을 쓰므로 인자 순서가 속성 선언 순서(`day, level, isToday, spokenLabel`)와 같아야 한다. `#Preview`나 다른 곳에서 `LawnCell(`을 부르는 곳이 없는지 `grep -n "LawnCell(" HabitTable/*.swift`로 확인한다(있으면 같이 고친다).

- [ ] **Step 5: 커밋**

```bash
git add HabitTable/HabitProgress.swift HabitTable/WeekMatrixView.swift HabitTable/LawnView.swift HabitTableTests/HabitProgressTests.swift
git commit -m "접근성 문구: 주 n회 목표 달성 읽기, 잔디 칸에 월 추가·단계 말 통일"
```

---

### Task 2: 할 일 빈 화면 문구를 오늘·앞으로·지난 날로 나누기

**Files:**
- Modify: `HabitTable/TodoProgress.swift` (함수 1개 추가)
- Modify: `HabitTable/TodoListView.swift:194-204` (`emptyCard`)
- Test: `HabitTableTests/TodoProgressTests.swift`

**Interfaces:**
- Consumes: `DayKey.make(_:calendar:)`
- Produces: `static func emptyState(day: Int, today: Int) -> (title: String, message: String)` — 두 인자 모두 DayKey

- [ ] **Step 1: 실패하는 테스트 쓰기**

`TodoProgressTests.swift` 클래스 맨 아래(닫는 `}` 바로 위)에 추가:

```swift
    // MARK: - 빈 화면 문구

    func testEmptyStateTodayFuturePast() {
        let today = TodoProgress.emptyState(day: 20261013, today: 20261013)
        XCTAssertEqual(today.title, "오늘 할 일을 추가해 보세요")
        XCTAssertEqual(today.message, "병원 예약, 택배 찾기처럼 하루짜리 일을 적어 두세요. 위의 날짜를 눌러 다른 날 할 일도 볼 수 있어요.")

        let tomorrow = TodoProgress.emptyState(day: 20261014, today: 20261013)
        XCTAssertEqual(tomorrow.title, "이 날은 할 일이 없어요")
        XCTAssertEqual(tomorrow.message, "아래 버튼으로 이 날 할 일을 미리 적어 둘 수 있어요.")

        let yesterday = TodoProgress.emptyState(day: 20261012, today: 20261013)
        XCTAssertEqual(yesterday.title, "이 날은 할 일이 없어요")
        XCTAssertEqual(yesterday.message, "아래 버튼으로 이 날 한 일을 적어 둘 수도 있어요.")
    }

    func testEmptyStateAcrossYearEnd() {
        XCTAssertEqual(TodoProgress.emptyState(day: 20270101, today: 20261231).message,
                       "아래 버튼으로 이 날 할 일을 미리 적어 둘 수 있어요.")
        XCTAssertEqual(TodoProgress.emptyState(day: 20261231, today: 20270101).message,
                       "아래 버튼으로 이 날 한 일을 적어 둘 수도 있어요.")
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

로컬 실행 불가. `emptyState`가 없어 컴파일 오류가 나야 정상이다. 기대 문구가 "바꿀 문구 표" 1번과 글자 그대로 같은지 확인한다.

- [ ] **Step 3: 함수 구현**

`TodoProgress.swift`의 `dayTitle` 아래(enum 닫는 `}` 위)에 추가:

```swift
    /// 할 일이 없는 날의 빈 화면 문구 (day·today는 DayKey).
    /// 오늘은 첫 안내, 앞으로의 날은 "미리 적어 둘", 지난 날은 "한 일을 적어 둘 수도".
    static func emptyState(day: Int, today: Int) -> (title: String, message: String) {
        if day == today {
            return ("오늘 할 일을 추가해 보세요",
                    "병원 예약, 택배 찾기처럼 하루짜리 일을 적어 두세요. 위의 날짜를 눌러 다른 날 할 일도 볼 수 있어요.")
        }
        if day > today {
            return ("이 날은 할 일이 없어요", "아래 버튼으로 이 날 할 일을 미리 적어 둘 수 있어요.")
        }
        return ("이 날은 할 일이 없어요", "아래 버튼으로 이 날 한 일을 적어 둘 수도 있어요.")
    }
```

- [ ] **Step 4: 뷰에 연결**

`TodoListView.swift`의 `emptyCard` 전체를 다음으로 바꾼다:

```swift
    private var emptyCard: some View {
        let copy = TodoProgress.emptyState(day: selectedKey, today: DayKey.make(today, calendar: calendar))
        return EmptyStateCard(
            title: copy.title,
            message: copy.message,
            buttonLabel: "할 일 추가"
        ) {
            editorTarget = .new
        }
    }
```

컴파일 확인: `emptyCard`는 `@ViewBuilder`가 아닌 계산 속성이므로 `let` 다음에 `return`이 꼭 있어야 한다. `isToday`는 "오늘로 이동" 버튼(같은 파일 100번째 줄 근처)에서 계속 쓰므로 지우지 않는다. `selectedKey`는 이미 있는 `Int` 속성(18번째 줄 근처)이다.

- [ ] **Step 5: 커밋**

```bash
git add HabitTable/TodoProgress.swift HabitTable/TodoListView.swift HabitTableTests/TodoProgressTests.swift
git commit -m "할 일 빈 화면: 지난 날에는 '미리' 대신 '한 일을 적어 둘 수도'"
```

---

### Task 3: 고정 문구 두 곳 + 안내 문서, push 후 CI 확인

**Files:**
- Modify: `HabitTable/HabitBoardView.swift:182`
- Modify: `HabitTable/HabitEditorView.swift:64`
- Modify: `CLAUDE.md:27`

**Interfaces:**
- Consumes: Task 1·2의 커밋(같은 브랜치)
- Produces: 없음

- [ ] **Step 1: 습관 빈 화면 설명**

`HabitBoardView.swift`:
```swift
            message: "매일 또는 원하는 요일에 할 습관을 추가하면, 이번 주 표와 잔디가 채워지기 시작해요.",
```
→
```swift
            message: "매일, 원하는 요일, 또는 일주일에 몇 번 할 습관을 추가하면, 이번 주 표와 잔디가 채워지기 시작해요.",
```

- [ ] **Step 2: 반복 방식 버튼**

`HabitEditorView.swift`:
```swift
                                Text("주 n회").tag(true)
```
→
```swift
                                Text("횟수 정하기").tag(true)
```
("요일 정하기"와 글자 수가 같아 segmented 너비는 그대로다.)

- [ ] **Step 3: CLAUDE.md 구조 설명**

`CLAUDE.md` 27번째 줄의 `요일 정하기 / 주 n회 전환`을 `요일 정하기 / 횟수 정하기 전환`으로 바꾼다. (코드 주석의 "주 n회"는 기능 이름이므로 그대로 둔다.)

- [ ] **Step 4: 남은 옛 문구가 없는지 확인**

```bash
grep -n '"주 n회"\|미리 적어 둘\|달성 0%\|"절반 미만"\|levelDescription' HabitTable/*.swift
```
Expected: `TodoProgress.swift`의 "미리 적어 둘" 한 줄만 나온다.

- [ ] **Step 5: 커밋**

```bash
git add HabitTable/HabitBoardView.swift HabitTable/HabitEditorView.swift CLAUDE.md
git commit -m "습관 빈 화면에 주 n회 안내, 반복 방식 버튼 '횟수 정하기'"
```

- [ ] **Step 6: push 후 CI 확인**

push는 새 브랜치 `feature/copy-polish`에만 한다.

```bash
git push -u origin feature/copy-polish
gh run list --branch feature/copy-polish --limit 1
gh run watch
```
Expected: "Build & run unit tests" 성공(새 테스트 5개 포함 모두 통과), 스크린샷 4장 생성.
실패하면 `gh run view --log-failed`로 오류를 보고 고친 뒤 다시 push한다.

```bash
gh run download -n screenshots -D "<스크래치패드>/copy-polish-shots"
```
스크린샷은 샘플 데이터라 빈 화면은 나오지 않는다. 습관 표와 잔디가 전과 똑같이 보이는지만 확인한다(이번 작업은 보이는 배치를 바꾸지 않는다).

- [ ] **Step 7: 실기기 확인 목록에 추가**

`CLAUDE.md` "실기기 확인 필요" 줄 끝에 `, VoiceOver의 잔디 칸("10월 9일, 절반 미만 달성")·주 n회 "목표 달성" 읽기, 반복 방식 버튼 '횟수 정하기'(큰 글자)`를 덧붙이고 커밋·push한다.

```bash
git add CLAUDE.md
git commit -m "실기기 확인 목록에 문구 다듬기 항목 추가"
git push
```
