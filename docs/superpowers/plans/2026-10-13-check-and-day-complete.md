# 체크 효과 · 하루 완성(꽃 + 토스트) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이번 주 표에서 빈 칸을 체크하면 칸이 튀고 체크가 그려지며 잎 세 장이 흩어지고, 오늘이 100%가 되면 잔디 오늘 칸에 꽃이 피고(오늘 처음 완성일 때만) 탭 바 위에 토스트가 뜬다.

**Architecture:** 판단 규칙(`isDayComplete`, `shouldCelebrate`)은 `HabitProgress`의 순수 함수로 두고 테스트한다. 움직임 수치는 새 파일 `Motion.swift` 한 곳에 모으고, 화면 조각은 파일 하나에 한 역할로 나눈다: `CheckCell.swift`(체크 효과), `BloomMark.swift`(꽃 그림), `DayCompleteToast.swift`(토스트와 표시 수정자). `HabitBoardView`는 체크 전후 진행률을 비교해 토스트를 띄우고, `LawnView`는 오늘 칸이 100%일 때 꽃을 그린다. 데이터 모델은 바꾸지 않는다(마지막 축하 날짜만 `@AppStorage`).

**Tech Stack:** Swift · SwiftUI(iOS 17: `KeyframeAnimator`, `AccessibilityNotification`) · XCTest. 로컬 빌드 불가(Windows) — 검증은 push 후 GitHub Actions(`.github/workflows/ios.yml`)의 단위 테스트와 스크린샷.

**Spec:**
- 규칙: `docs/superpowers/specs/2026-10-09-day-complete-design.md`
- 모양·움직임 수치: 춘배 캔버스 "움직임 시안" 보드(`project/Motion.dc.html`)와 "습관 탭 첫 화면" 보드(`project/AppHome.dc.html`) — https://claude.ai/artifact/S6aQnV8dU9RbRNJGtKXGeP . 이 계획의 수치는 모두 그 보드에서 그대로 옮겼다.

**작성:** 춘수 🖌️(프론트엔드 디자이너), 2026-10-13. 브랜치 `feature/weekly-target`에서 이어서 작업한다.

## Global Constraints

- 최소 iOS 17. iOS 18 이상 API(`.onScrollGeometryChange`, `Animation.smooth(extraBounce:)`의 새 오버로드 등) 금지.
- 색은 `Theme` 토큰만 쓴다. 새 색은 반드시 `Color(light:dark:)` 쌍으로 만든다.
- 글꼴은 `.font(.spoqa(크기, 굵기, relativeTo: …))`.
- 움직임 수치(시간·곡선·거리)는 `Motion`에만 둔다. 뷰 안에 숫자를 흩어 놓지 않는다(잎의 비행 거리·각도처럼 그 그림에만 쓰는 모양 값은 그 파일 안에 둔다).
- '동작 줄이기'(`accessibilityReduceMotion`)에서는 튐·그리기·잎·꽃 피기·미끄러짐 없이 바로 바뀐다. 토스트만 0.2초 흐려지며 나타나고 사라진다.
- 체크를 **풀 때**는 움직임 없이 바로 비운다.
- 완성 기준 = 잔디 100%(`total > 0 && done >= total`). 토스트는 **오늘 칸을 체크해서** 오늘이 처음 완성될 때만, 하루 한 번(`@AppStorage("lastCelebratedDay")`, DayKey 정수).
- 토스트 문구: 제목 "오늘 습관을 모두 해냈어요" / 보조 "잔디에 꽃이 피었어요". VoiceOver 알림 문구: "오늘 습관을 모두 해냈어요". 잔디 오늘 칸 라벨 뒤에 ", 꽃이 피었어요".
- UI 문구는 한국어 해요체.
- 저장 모델(`Habit`, `TodoItem`)에 필드를 추가하지 않는다.
- 코드를 바꾸면 컴파일 가능성을 특히 꼼꼼히 확인한다(로컬에서 못 돌림). 특히 `@ViewBuilder` 안의 `let`, `CGFloat`/`Double` 섞임, `KeyframeTrack` 키패스 타입.

## Review Focus

1. **빠르게 연타**(빈 칸 → 체크 → 해제 → 체크를 1초 안에) → 매번 처음부터 다시 튀고, 해제 순간엔 바로 빈 칸이 되며, 잎이 화면에 남지 않는다. 토스트는 하루 한 번만. (Task 3 Step 4 수동 확인 항목, Task 1 `testShouldNotCelebrateTwiceSameDay`)
2. **지난주를 보며 지난 날짜를 체크해 그날이 100%가 됨** → 토스트도 꽃 움직임도 없다(지난 100%는 진한 초록만). (Task 1 `testShouldNotCelebratePastDay`)
3. **오늘 할 습관이 주 n회 하나뿐이고 그것을 체크** → 1/1이라 완성, 토스트가 뜬다. 반대로 그 체크를 풀면 0/0이라 꽃이 사라지고 토스트도 닫힌다. (Task 1 `testDayCompleteWithOnlyWeeklyHabitChecked`, `testShouldNotCelebrateUncheck`; Task 5 해제 시 토스트 닫기)
4. **미완료 습관을 삭제·수정해서 오늘이 100%가 됨** → 꽃은 보이지만(상태), 토스트는 뜨지 않는다(체크 동작에서만 판단). (Task 5 — `toggle` 안에서만 `shouldCelebrate`를 부른다)
5. **큰 글씨(접근성 크기)·다크 모드에서 토스트** → 글자가 잘리지 않고 줄바꿈되며, 다크에서도 바탕과 글자 대비가 4.5:1 이상. (Task 2 토큰 대비 수치, Task 5 `fixedSize(vertical)`, Task 6 다크 스크린샷)

---

### Task 1: 하루 완성 판단 규칙

**Files:**
- Modify: `HabitTable/HabitProgress.swift` (`toggled(_:key:)` 바로 아래, `// MARK: - 표시용` 위에 새 MARK 추가)
- Test: `HabitTableTests/HabitProgressTests.swift` (클래스 맨 끝, 닫는 `}` 위)

**Interfaces:**
- Consumes (이미 있음): `struct DayProgress: Equatable { let done: Int; let total: Int }`, `HabitProgress.progress(_:on:calendar:)`, 테스트의 `TestHabit`, `date(_:_:_:)`, `cal`
- Produces:
  - `static func isDayComplete(_ p: DayProgress) -> Bool`
  - `static func shouldCelebrate(before: DayProgress, after: DayProgress, dayKey: Int, todayKey: Int, lastCelebrated: Int) -> Bool`

- [ ] **Step 1: 실패하는 테스트 작성** — `HabitProgressTests.swift` 클래스 닫는 `}` 바로 위에 붙인다.

```swift
    // MARK: - 하루 완성

    func testIsDayComplete() {
        XCTAssertTrue(HabitProgress.isDayComplete(DayProgress(done: 2, total: 2)))
        XCTAssertFalse(HabitProgress.isDayComplete(DayProgress(done: 1, total: 2)))
        XCTAssertFalse(HabitProgress.isDayComplete(DayProgress(done: 0, total: 0)))
    }

    /// 오늘 = 2026-10-06(DayKey 20261006)
    private func celebrate(_ before: (Int, Int), _ after: (Int, Int),
                           day: Int = 20261006, last: Int = 0) -> Bool {
        HabitProgress.shouldCelebrate(
            before: DayProgress(done: before.0, total: before.1),
            after: DayProgress(done: after.0, total: after.1),
            dayKey: day, todayKey: 20261006, lastCelebrated: last
        )
    }

    func testShouldCelebrateFirstCompletion() {
        XCTAssertTrue(celebrate((1, 2), (2, 2)))
    }

    func testShouldNotCelebrateWhenAlreadyComplete() {
        XCTAssertFalse(celebrate((2, 2), (3, 3)))
    }

    func testShouldNotCelebratePastDay() {
        XCTAssertFalse(celebrate((1, 2), (2, 2), day: 20261005))
    }

    func testShouldNotCelebrateTwiceSameDay() {
        XCTAssertFalse(celebrate((1, 2), (2, 2), last: 20261006))
    }

    func testShouldCelebrateAgainNextDay() {
        XCTAssertTrue(celebrate((1, 2), (2, 2), last: 20261005))
    }

    func testShouldNotCelebrateEmptyDay() {
        XCTAssertFalse(celebrate((0, 0), (0, 0)))
    }

    func testShouldNotCelebrateUncheck() {
        XCTAssertFalse(celebrate((2, 2), (1, 2)))
        XCTAssertFalse(celebrate((1, 1), (0, 0)))   // 주 n회 하나만 체크했다가 풂
    }

    /// 오늘 셈에 들어가는 습관이 주 n회 하나뿐: 체크하면 1/1 → 완성
    func testDayCompleteWithOnlyWeeklyHabitChecked() {
        let today = date(2026, 10, 6)
        let key = DayKey.make(today, calendar: cal)
        let before = TestHabit(weekdays: Array(1...7), createdDay: 20260901, weeklyTarget: 3)
        var after = before
        after.completedDays = [key]

        let p0 = HabitProgress.progress([before], on: today, calendar: cal)
        let p1 = HabitProgress.progress([after], on: today, calendar: cal)
        XCTAssertEqual(p0, DayProgress(done: 0, total: 0))
        XCTAssertEqual(p1, DayProgress(done: 1, total: 1))
        XCTAssertTrue(HabitProgress.shouldCelebrate(
            before: p0, after: p1, dayKey: key, todayKey: key, lastCelebrated: 0))
    }
```

- [ ] **Step 2: 구현** — `HabitProgress.swift`의 `toggled(_:key:)` 함수 닫는 `}` 다음 줄에 붙인다.

```swift

    // MARK: - 하루 완성

    /// 잔디 100%와 같은 기준 (할 습관이 있고 모두 했음)
    static func isDayComplete(_ p: DayProgress) -> Bool {
        p.total > 0 && p.done >= p.total
    }

    /// 체크 동작 직후 '하루 완성' 토스트를 띄울지.
    /// 오늘 칸을 체크해 오늘이 처음 완성됐고, 오늘 아직 축하하지 않았을 때만 true.
    static func shouldCelebrate(before: DayProgress, after: DayProgress,
                                dayKey: Int, todayKey: Int, lastCelebrated: Int) -> Bool {
        dayKey == todayKey
            && !isDayComplete(before)
            && isDayComplete(after)
            && lastCelebrated != todayKey
    }
```

- [ ] **Step 3: 커밋하고 CI에서 테스트 확인**

```bash
git add HabitTable/HabitProgress.swift HabitTableTests/HabitProgressTests.swift
git commit -m "하루 완성 판단 규칙(isDayComplete, shouldCelebrate)과 테스트 추가"
git push
gh run watch
```
Expected: `Build & run unit tests` 단계 통과, 새 테스트 9개 PASS. 실패하면 `gh run view --log-failed`.

---

### Task 2: 꽃·토스트 색 토큰, 움직임 수치, 꽃 그림

**Files:**
- Modify: `HabitTable/Theme.swift` (`saturday` 다음 줄)
- Create: `HabitTable/Motion.swift`
- Create: `HabitTable/BloomMark.swift`

**Interfaces:**
- Produces:
  - `Theme.bloom`, `Theme.bloomCenter`, `Theme.toast`, `Theme.toastText`, `Theme.toastSubtext` (모두 `Color`)
  - `enum Motion` — `static func pop(_ duration: Double) -> Animation`, 상수 `cellPop`, `checkDrawDelay`, `checkDraw`, `leafDelay`, `leafBurst`, `petal`, `petalStagger`, `bloomCenterDelay`, `toastIn`, `toastDelay`, `toastStay: Duration`, `fade`, `lawnColor` (나머지는 `Double`, 초 단위)
  - `struct BloomMark: View { init(animated: Bool) }` — 정사각형으로 늘어나는 꽃 그림

색 결정:
- `bloom`, `bloomCenter`: 춘배 제안 토큰 그대로(캔버스 확정).
- `toast*`: 라이트는 캔버스 값(#1B2A1E 바탕, 흰 글자, #BFE3A5 보조). **다크는 캔버스에 없어 춘수가 정함** — 바탕을 뒤집어 밝은 카드(#E6F0E3)로 띄운다. 대비: 다크 보조 #226F35 on #E6F0E3 ≈ 5.3:1, 라이트 보조 #BFE3A5 on #1B2A1E ≈ 10.6:1. 춘배 확인 대상으로 보고에 적는다.

- [ ] **Step 1: 색 토큰 추가** — `Theme.swift`의 `static let saturday = …` 줄 바로 아래에 붙인다.

```swift
    // 하루 완성 꽃 (꽃잎 / 가운데)
    static let bloom = Color(light: 0xFFB3C7, dark: 0xC23B66)
    static let bloomCenter = Color(light: 0xF2B33D, dark: 0xFFD966)
    // 하루 완성 토스트: 라이트는 어두운 바탕, 다크는 밝은 바탕으로 뒤집어 화면 위에 뜬다
    static let toast = Color(light: 0x1B2A1E, dark: 0xE6F0E3)
    static let toastText = Color(light: 0xFFFFFF, dark: 0x0F1A12)
    static let toastSubtext = Color(light: 0xBFE3A5, dark: 0x226F35)
```

- [ ] **Step 2: `Motion.swift` 만들기**

```swift
import SwiftUI

/// 움직임 수치 (춘배 캔버스 "움직임 시안", 2026-10-09 확정). 시간은 초.
enum Motion {
    /// 통통 튀는 곡선 — cubic-bezier(.34, 1.56, .64, 1)
    static func pop(_ duration: Double) -> Animation {
        .timingCurve(0.34, 1.56, 0.64, 1, duration: duration)
    }

    // 칸 체크
    static let cellPop = 0.38          // 칸이 0.4배에서 1.08배를 거쳐 1배로
    static let checkDrawDelay = 0.12   // 칸이 커지기 시작하고 체크를 그리기까지
    static let checkDraw = 0.26        // 체크 표시가 선을 따라 그려지는 시간
    static let leafDelay = 0.08
    static let leafBurst = 0.56        // 잎 세 장이 흩어지며 사라지는 시간

    // 하루 완성 꽃
    static let petal = 0.3             // 꽃잎 한 장이 피는 시간
    static let petalStagger = 0.05     // 꽃잎 사이 간격
    static let bloomCenterDelay = 0.26 // 가운데가 찍히는 시각

    // 하루 완성 토스트
    static let toastIn = 0.52
    static let toastDelay = 0.26       // 꽃잎이 먼저 피기 시작한 뒤 올라온다
    static let toastStay: Duration = .seconds(3)

    // 공통
    static let fade = 0.2              // 동작 줄이기, 토스트 사라짐
    static let lawnColor = 0.32        // 잔디 칸 색이 바뀌는 시간
}
```

- [ ] **Step 3: `BloomMark.swift` 만들기** — 시안의 24×24 그림(꽃잎 반지름 4 다섯 장 + 가운데 반지름 3)을 주어진 크기에 맞춰 그린다.

```swift
import SwiftUI

/// 하루 완성 꽃: 꽃잎 다섯 장 + 가운데. 24×24 그림을 받은 크기에 맞춰 그린다.
/// - animated: 나타날 때 꽃잎이 0.05초 간격으로 톡톡 피고, 가운데가 마지막에 찍힌다.
/// - '동작 줄이기'에서는 처음부터 핀 모습으로 나타난다.
struct BloomMark: View {
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false

    /// 꽃잎 중심 (24×24 기준, 위에서 시계 방향)
    private static let petals: [CGPoint] = [
        CGPoint(x: 12, y: 6.8), CGPoint(x: 16.95, y: 10.39), CGPoint(x: 15.06, y: 16.21),
        CGPoint(x: 8.94, y: 16.21), CGPoint(x: 7.05, y: 10.39),
    ]

    private var shown: Bool { opened || !animated || reduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height) / 24
            ZStack {
                ForEach(Self.petals.indices, id: \.self) { i in
                    dot(Theme.bloom, center: Self.petals[i], radius: 4, scale: s,
                        delay: Double(i) * Motion.petalStagger)
                }
                dot(Theme.bloomCenter, center: CGPoint(x: 12, y: 12), radius: 3, scale: s,
                    delay: Motion.bloomCenterDelay)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear { opened = true }
    }

    private func dot(_ color: Color, center: CGPoint, radius: CGFloat, scale s: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: radius * 2 * s, height: radius * 2 * s)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .animation(Motion.pop(Motion.petal).delay(delay), value: opened)
            .position(x: center.x * s, y: center.y * s)
    }
}

#Preview {
    HStack(spacing: 24) {
        BloomMark(animated: false).frame(width: 26, height: 26)
        BloomMark(animated: true).frame(width: 60, height: 60)
    }
    .padding()
    .background(Theme.grass4)
}
```

- [ ] **Step 4: 컴파일 점검(눈으로)** — `CGFloat * Double` 섞임 없음 확인: `radius`와 `s`는 `CGFloat`, `center.x`는 `CGFloat`, `delay`만 `Double`. `Motion.pop(...)`은 `Animation`을 돌려주고 `.delay(Double)`을 받는다.

- [ ] **Step 5: 커밋하고 CI 빌드 확인**

```bash
git add HabitTable/Theme.swift HabitTable/Motion.swift HabitTable/BloomMark.swift
git commit -m "하루 완성 꽃 그림, 꽃·토스트 색 토큰, 움직임 수치 모음 추가"
git push
gh run watch
```
Expected: 빌드·테스트 통과(새 파일은 `project.yml`의 `sources: [HabitTable]`로 자동 포함).

---

### Task 3: 체크 효과 (칸 튐 · 체크 그리기 · 잎 세 장)

**Files:**
- Create: `HabitTable/CheckCell.swift` (`WeekMatrixView.swift`의 `CheckCell`을 옮기고 효과를 더함)
- Modify: `HabitTable/WeekMatrixView.swift:162-203` (`/// 체크 칸 하나` 주석부터 `CheckCell` 구조체 끝까지 삭제)
- Modify: `HabitTable/HabitBoardView.swift:191-197` (`toggle`에서 `withAnimation` 제거 — Task 5에서 다시 고침)

**Interfaces:**
- Consumes: `Motion.cellPop`, `checkDrawDelay`, `checkDraw`, `leafDelay`, `leafBurst`; `Theme.grass0…3`, `Theme.onGrass`, `Theme.dash`, `Theme.restMark`
- Produces: `struct CheckCell: View { enum CellState { case done, missed, future, rest }; init(state: CellState, action: @escaping () -> Void) }` — 지금과 같은 이름·생성자라 `WeekMatrixView`의 호출부는 그대로다.

시안 수치(`Motion.dc.html`의 `.tap-pop`, `.draw`, `.b1–.b3`):
- 칸: 0→60% 구간에 0.4배·투명 → 1.08배·불투명, 60→100% 구간에 1배. 총 0.38초.
- 체크: 0.12초 기다렸다가 0.26초 동안 ease-out으로 그린다. 선 굵기 2.4, 끝 둥글게, 12×12 안의 `M2.5 6.3 L5 8.8 L9.6 3.4`.
- 잎: 0.08초 기다렸다가 0.56초 ease-out. 잎마다 (x, y, 회전) = (−20, −22, −40°) grass2, (2, −30, 10°) grass3, (22, −20, 45°) grass1. 크기 0.5→1배, 불투명 1→0. 기다리는 동안은 보이지 않는다.
- 해제·동작 줄이기: 움직임 없음.

- [ ] **Step 1: `CheckCell.swift` 만들기**

```swift
import SwiftUI

/// 체크 칸 하나.
/// 빈 칸을 눌러 채우면 칸이 통통 튀고, 체크가 선을 따라 그려지고, 잎 세 장이 흩어진다.
/// 풀 때와 '동작 줄이기'에서는 움직임 없이 바로 바뀐다. 빠르게 다시 눌러도 처음부터 다시 재생된다.
struct CheckCell: View {
    enum CellState { case done, missed, future, rest }

    let state: CellState
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 빈 칸을 채울 때마다 1씩 늘려 움직임을 처음부터 다시 재생한다
    @State private var playCount = 0

    private let size: CGFloat = 26
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 8, style: .continuous) }

    var body: some View {
        switch state {
        case .rest:
            Capsule()
                .fill(Theme.restMark)
                .frame(width: 5, height: 2)
                .frame(width: size, height: size)
        case .future:
            shape
                .strokeBorder(Theme.dash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: size, height: size)
        case .done, .missed:
            Button {
                if state == .missed && !reduceMotion { playCount += 1 }
                action()
            } label: {
                KeyframeAnimator(initialValue: CheckPlay(), trigger: playCount) { play in
                    face(play)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.4)
                        LinearKeyframe(1.08, duration: Motion.cellPop * 0.6, timingCurve: .easeOut)
                        LinearKeyframe(1, duration: Motion.cellPop * 0.4, timingCurve: .easeInOut)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: Motion.cellPop * 0.6, timingCurve: .easeOut)
                    }
                    KeyframeTrack(\.draw) {
                        MoveKeyframe(0)
                        LinearKeyframe(0, duration: Motion.checkDrawDelay)
                        LinearKeyframe(1, duration: Motion.checkDraw, timingCurve: .easeOut)
                    }
                    KeyframeTrack(\.leaf) {
                        MoveKeyframe(0)
                        LinearKeyframe(0, duration: Motion.leafDelay)
                        LinearKeyframe(1, duration: Motion.leafBurst, timingCurve: .easeOut)
                    }
                }
                .frame(width: 34, height: 34) // 누르는 영역은 조금 넉넉하게
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: state == .done)
        }
    }

    @ViewBuilder
    private func face(_ play: CheckPlay) -> some View {
        if state == .done {
            ZStack {
                shape
                    .fill(Theme.grass3)
                    .frame(width: size, height: size)
                    .overlay {
                        CheckmarkShape()
                            .trim(from: 0, to: play.draw)
                            .stroke(Theme.onGrass, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 12, height: 12)
                    }
                    .scaleEffect(play.scale)
                    .opacity(play.opacity)

                ForEach(Self.leaves.indices, id: \.self) { i in
                    leaf(Self.leaves[i], progress: play.leaf)
                }
            }
        } else {
            shape
                .fill(Theme.grass0)
                .frame(width: size, height: size)
        }
    }

    // MARK: - 잎 세 장

    private struct Leaf {
        let dx: CGFloat
        let dy: CGFloat
        let angle: Double
        let color: Color
    }

    /// 칸 가운데에서 왼쪽 위·위·오른쪽 위로 흩어진다 (시안 burst1~3)
    private static let leaves: [Leaf] = [
        Leaf(dx: -20, dy: -22, angle: -40, color: Theme.grass2),
        Leaf(dx: 2, dy: -30, angle: 10, color: Theme.grass3),
        Leaf(dx: 22, dy: -20, angle: 45, color: Theme.grass1),
    ]

    /// progress 0 = 기다리는 중(안 보임), 0→1 = 날아가며 옅어짐, 1 = 끝(안 보임)
    private func leaf(_ leaf: Leaf, progress p: Double) -> some View {
        LeafShape()
            .fill(leaf.color)
            .frame(width: 12, height: 12)
            .scaleEffect(0.5 + 0.5 * p)
            .rotationEffect(.degrees(leaf.angle * p))
            .offset(x: leaf.dx * CGFloat(p), y: leaf.dy * CGFloat(p))
            .opacity(p > 0 ? 1 - p : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 체크 효과 한 번의 움직임 값. 쉬고 있을 때는 모두 1(다 그려진 칸, 잎은 사라진 뒤).
private struct CheckPlay {
    var scale: Double = 1
    var opacity: Double = 1
    var draw: Double = 1
    var leaf: Double = 1
}

/// 체크 표시 (12×12 기준 M2.5 6.3 L5 8.8 L9.6 3.4)
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 12
        var p = Path()
        p.move(to: CGPoint(x: 2.5 * s, y: 6.3 * s))
        p.addLine(to: CGPoint(x: 5 * s, y: 8.8 * s))
        p.addLine(to: CGPoint(x: 9.6 * s, y: 3.4 * s))
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// 잎 (12×12 기준 M1 11 C1 5 5 1 11 1 C11 7 7 11 1 11 Z)
private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 12
        var p = Path()
        p.move(to: CGPoint(x: 1 * s, y: 11 * s))
        p.addCurve(to: CGPoint(x: 11 * s, y: 1 * s),
                   control1: CGPoint(x: 1 * s, y: 5 * s), control2: CGPoint(x: 5 * s, y: 1 * s))
        p.addCurve(to: CGPoint(x: 1 * s, y: 11 * s),
                   control1: CGPoint(x: 11 * s, y: 7 * s), control2: CGPoint(x: 7 * s, y: 11 * s))
        p.closeSubpath()
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

#Preview {
    struct Demo: View {
        @State private var done = false
        var body: some View {
            CheckCell(state: done ? .done : .missed) { done.toggle() }
                .padding(40)
                .background(Theme.card)
        }
    }
    return Demo()
}
```

- [ ] **Step 2: `WeekMatrixView.swift`에서 옛 `CheckCell` 지우기** — `/// 체크 칸 하나`(162줄) 주석부터 `CheckCell` 구조체를 닫는 `}`(203줄)까지 통째로 지운다. 위의 `DayHeader`와 아래의 `/// 주 n회 습관의 그 주 횟수` 주석·`WeeklyBadge`는 그대로 둔다. `state(of:on:)`의 `CheckCell.CellState` 참조는 새 파일의 타입을 그대로 가리킨다.

- [ ] **Step 3: 해제할 때 바로 비우기** — `HabitBoardView.swift`의 `toggle`에서 `withAnimation`을 걷어 낸다(체크 효과는 칸이 직접 재생하고, 해제는 즉시여야 한다).

바꾸기 전:
```swift
        withAnimation(.snappy(duration: 0.2)) {
            habit.completedDays = HabitProgress.toggled(habit.completedDays, key: key)
        }
```
바꾼 뒤:
```swift
        habit.completedDays = HabitProgress.toggled(habit.completedDays, key: key)
```

- [ ] **Step 4: 컴파일 점검(눈으로)**
  - `KeyframeTrack(\.scale)` 등 키패스가 `CheckPlay`의 `Double` 속성과 맞는지. `LinearKeyframe(_:duration:timingCurve:)`의 `timingCurve`는 `UnitCurve`(`.easeOut`, `.easeInOut`).
  - `scaleEffect(Double)`, `trim(to: Double)`은 Swift 5.5+의 `CGFloat`↔`Double` 암시 변환으로 컴파일된다. `CGFloat * Double` 곱셈은 모호해질 수 있어 잎 위치는 `leaf.dx * CGFloat(p)`로 써 두었다.
  - `private struct CheckPlay`(파일 범위 private = fileprivate)는 `body`의 `some View` 안에 숨겨지므로 접근 수준 문제가 없다.
  - 실기기·시뮬레이터 수동 확인 목록(춘봉이에게 넘김): 빈 칸 탭 → 튐·체크·잎 / 연타 → 매번 처음부터, 잎 남지 않음 / 체크 해제 → 즉시 빈 칸 / 동작 줄이기 → 바로 채움.

- [ ] **Step 5: 커밋하고 CI 확인**

```bash
git add HabitTable/CheckCell.swift HabitTable/WeekMatrixView.swift HabitTable/HabitBoardView.swift
git commit -m "체크 효과 추가: 칸 튐, 체크 그리기, 잎 세 장 (해제·동작 줄이기는 즉시)"
git push
gh run watch
gh run download -n screenshots
```
Expected: 빌드·테스트 통과. `calendar-light/dark.png`에서 완료 칸의 체크가 SF 심볼 대신 새 체크 선(굵기 2.4, 둥근 끝)으로 다 그려진 상태로 보인다.

---

### Task 4: 잔디 오늘 칸에 꽃

**Files:**
- Modify: `HabitTable/LawnView.swift`

**Interfaces:**
- Consumes: `BloomMark(animated:)`, `Motion.lawnColor`, `ProgressLevel.full`
- Produces: `LawnView(habits:today:calendar:animateBloom:)` — `animateBloom: Bool`은 새 매개변수(기본값 `false`). `true`면 꽃이 나타날 때 피는 움직임을 재생한다.

시안: 오늘 칸이 100%(`level == .full`)인 동안만 칸 오른쪽 아래(여백 3)에 26×26 꽃. 지난 100%인 날엔 꽃이 없다. 칸 색은 0.32초에 걸쳐 바뀐다.

- [ ] **Step 1: `LawnView`에 매개변수 추가** — `let calendar: Calendar` 아래에:

```swift
    /// 꽃이 나타날 때 피는 움직임을 보일지 (사용자가 체크한 뒤에만 true. 앱을 켰을 때 이미 핀 꽃은 그냥 보인다)
    var animateBloom = false
```

- [ ] **Step 2: 칸 만드는 곳 바꾸기** — `ForEach(dates, id: \.self) { date in … }` 블록을 아래로 바꾼다.

```swift
                ForEach(dates, id: \.self) { date in
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    let cellLevel = level(on: date)
                    LawnCell(
                        day: calendar.component(.day, from: date),
                        level: cellLevel,
                        isToday: isToday,
                        // .full은 미래가 아니고 total > 0 && done >= total — HabitProgress.isDayComplete와 같다
                        bloom: isToday && cellLevel == .full,
                        animateBloom: animateBloom
                    )
                }
```

- [ ] **Step 3: `LawnCell`에 꽃·색 전환·라벨** — `LawnCell` 구조체 전체를 아래로 바꾼다.

```swift
private struct LawnCell: View {
    let day: Int
    let level: ProgressLevel
    let isToday: Bool
    /// 오늘이 100%일 때만 true
    let bloom: Bool
    let animateBloom: Bool

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 7, style: .continuous) }

    var body: some View {
        Group {
            if level == .future {
                shape.strokeBorder(Theme.dash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else {
                shape.fill(Theme.color(for: level))
                    .animation(.easeInOut(duration: Motion.lawnColor), value: level)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            Text("\(day)")
                .font(.spoqa(10.5, .bold, relativeTo: .caption2))
                .monospacedDigit()
                .foregroundStyle(Theme.numberColor(for: level))
                .padding(.leading, 5)
                .padding(.top, 4)
        }
        .overlay(alignment: .bottomTrailing) {
            if bloom {
                BloomMark(animated: animateBloom)
                    .frame(width: 26, height: 26)
                    .padding(3)
            }
        }
        .overlay {
            if isToday {
                shape.inset(by: -3).stroke(Theme.soil, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day)일 \(levelDescription)" + (bloom ? ", 꽃이 피었어요" : ""))
    }

    private var levelDescription: String {
        switch level {
        case .none: return "할 습관 없음"
        case .zero: return "달성 0%"
        case .low: return "절반 미만"
        case .mid: return "절반 이상"
        case .high: return "대부분 달성"
        case .full: return "모두 달성"
        case .future: return "아직 안 온 날"
        }
    }
}
```

- [ ] **Step 4: `HabitBoardView`에서 넘기기** — `@State private var habitToDelete: Habit?` 아래에:

```swift
    /// 사용자가 한 번이라도 체크한 뒤에는 꽃이 필 때 움직임을 보인다
    @State private var animateBloom = false
```
`toggle` 안, `habit.completedDays = …` 줄 바로 위에:
```swift
        animateBloom = true
```
`LawnView(habits: habits, today: today, calendar: calendar)`를 다음으로 바꾼다:
```swift
                LawnView(habits: habits, today: today, calendar: calendar, animateBloom: animateBloom)
```

- [ ] **Step 5: 컴파일 점검(눈으로)** — `ForEach` 빌더 안의 `let`은 Swift 5.9에서 허용(이미 `WeekMatrixView`가 같은 방식). `ProgressLevel`은 `Equatable`이라 `.animation(_:value:)`에 쓸 수 있다. `LawnView`의 기존 호출부는 이 한 곳뿐이다(`grep -n "LawnView(" HabitTable`으로 확인).

- [ ] **Step 6: 커밋하고 CI 확인**

```bash
git add HabitTable/LawnView.swift HabitTable/HabitBoardView.swift
git commit -m "잔디 오늘 칸이 100%일 때 꽃 표시, 칸 색 0.32초 전환"
git push
gh run watch
```
Expected: 빌드·테스트 통과. (샘플 데이터의 오늘은 100%가 아니라 지금 스크린샷엔 꽃이 없다 — Task 6에서 확인.)

---

### Task 5: 하루 완성 토스트

**Files:**
- Create: `HabitTable/DayCompleteToast.swift`
- Modify: `HabitTable/HabitBoardView.swift`

**Interfaces:**
- Consumes: `HabitProgress.progress`, `isDayComplete`, `shouldCelebrate`(Task 1), `BloomMark`, `Theme.toast*`, `Motion.*`
- Produces:
  - `struct DayCompleteToast: View { init(onClose: @escaping () -> Void) }`
  - `extension View { func dayCompleteToast(isPresented: Binding<Bool>, autoDismiss: Bool = true) -> some View }`

시안(`.toast`, 토스트 버튼 스타일): 좌우 16, 탭 바 위 12, 모서리 18, 안쪽 위아래 14·좌우 18, 꽃 28, 간격 12, 제목 15 bold / 보조 13 regular 간격 1. 들어올 때 0.26초 뒤 0.52초 동안 40pt 아래에서 튀며 올라옴. 3초 뒤 사라지고, 누르면 바로 닫힘. 동작 줄이기: 0.2초 흐려지며 나타나고 사라짐.

- [ ] **Step 1: `DayCompleteToast.swift` 만들기**

```swift
import SwiftUI

/// 하루 완성 토스트: "오늘 습관을 모두 해냈어요 / 잔디에 꽃이 피었어요". 누르면 닫힌다.
struct DayCompleteToast: View {
    let onClose: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        Button(action: onClose) {
            HStack(spacing: 12) {
                BloomMark(animated: true)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("오늘 습관을 모두 해냈어요")
                        .font(.spoqa(15, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.toastText)
                    Text("잔디에 꽃이 피었어요")
                        .font(.spoqa(13, .regular, relativeTo: .footnote))
                        .foregroundStyle(Theme.toastSubtext)
                }
                .fixedSize(horizontal: false, vertical: true)   // 큰 글씨에서 줄바꿈되며 늘어남
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.toast))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("오늘 습관을 모두 해냈어요. 잔디에 꽃이 피었어요")
        .accessibilityHint("누르면 닫혀요")
    }
}

/// 화면 아래(탭 바 바로 위)에 하루 완성 토스트를 띄운다.
private struct DayCompleteToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let autoDismiss: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .offset(y: 40).combined(with: .opacity), removal: .opacity)
    }

    private var animation: Animation {
        if !isPresented || reduceMotion { return .easeOut(duration: Motion.fade) }
        return Motion.pop(Motion.toastIn).delay(Motion.toastDelay)
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ZStack {
                    if isPresented {
                        DayCompleteToast { isPresented = false }
                            .transition(transition)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .animation(animation, value: isPresented)
            }
            .onChange(of: isPresented) { _, shown in
                if shown {
                    AccessibilityNotification.Announcement("오늘 습관을 모두 해냈어요").post()
                }
            }
            .task(id: isPresented) {
                guard isPresented, autoDismiss else { return }
                try? await Task.sleep(for: Motion.toastStay)
                guard !Task.isCancelled else { return }
                isPresented = false
            }
    }
}

extension View {
    /// 하루 완성 토스트. autoDismiss가 false면 3초 뒤에 닫지 않는다(스크린샷용).
    func dayCompleteToast(isPresented: Binding<Bool>, autoDismiss: Bool = true) -> some View {
        modifier(DayCompleteToastModifier(isPresented: isPresented, autoDismiss: autoDismiss))
    }
}

#Preview {
    Theme.background
        .dayCompleteToast(isPresented: .constant(true), autoDismiss: false)
}
```

- [ ] **Step 2: `HabitBoardView`에 상태 추가** — `@AppStorage(ReminderSettings.minutesKey) …` 줄 아래에:

```swift
    /// 마지막으로 하루 완성을 축하한 날 (DayKey). 같은 날 두 번 띄우지 않는다.
    @AppStorage("lastCelebratedDay") private var lastCelebratedDay = 0
    @State private var showDayComplete = false
```

- [ ] **Step 3: 토스트 붙이기** — `.background(Theme.background)` 바로 아래 줄에:

```swift
        .dayCompleteToast(isPresented: $showDayComplete)
```
(`ScrollView`에 붙으므로 탭 바 위, 스크롤 영역 아래쪽에 뜬다.)

- [ ] **Step 4: `toggle`에서 판단하기** — `toggle` 함수 전체를 아래로 바꾼다(Task 3·4에서 고친 내용 포함).

```swift
    private func toggle(_ habit: Habit, _ date: Date) {
        guard HabitProgress.canToggle(date: date, today: today, calendar: calendar) else { return }
        let key = DayKey.make(date, calendar: calendar)
        let todayKey = DayKey.make(today, calendar: calendar)
        let before = HabitProgress.progress(habits, on: date, calendar: calendar)

        animateBloom = true
        habit.completedDays = HabitProgress.toggled(habit.completedDays, key: key)

        let after = HabitProgress.progress(habits, on: date, calendar: calendar)
        if HabitProgress.shouldCelebrate(before: before, after: after, dayKey: key,
                                         todayKey: todayKey, lastCelebrated: lastCelebratedDay) {
            lastCelebratedDay = todayKey
            showDayComplete = true
        } else if key == todayKey && !HabitProgress.isDayComplete(after) {
            showDayComplete = false   // 해제해서 100%가 깨지면 떠 있던 토스트도 닫는다
        }
    }
```

- [ ] **Step 5: 컴파일 점검(눈으로)**
  - `habits`는 `[Habit]`, `Habit`은 `HabitSchedulable`이라 `progress`의 제네릭에 맞는다. `habit`은 `@Model` 클래스라 바꾼 직후 `habits`로 다시 세면 바뀐 값이 보인다.
  - `AnyTransition.offset(y:)`는 `offset(x: CGFloat = 0, y: CGFloat = 0)` — `.offset(y: 40)` 가능.
  - `AccessibilityNotification.Announcement(_:)`와 `.post()`는 iOS 17+.
  - `.task(id:)`의 `id`는 `Equatable`(`Bool`) — 가능. 탭해서 닫으면 `id`가 바뀌어 기다리던 작업이 취소된다.

- [ ] **Step 6: 커밋하고 CI 확인**

```bash
git add HabitTable/DayCompleteToast.swift HabitTable/HabitBoardView.swift
git commit -m "하루 완성 토스트 추가: 오늘 칸 체크로 처음 완성될 때 하루 한 번, 3초 뒤 닫힘"
git push
gh run watch
```
Expected: 빌드·테스트 통과.

---

### Task 6: 스크린샷으로 꽃·토스트 확인, 문서 갱신

**Files:**
- Modify: `HabitTable/HabitTableApp.swift` (`SampleData.insert`, 앱 init)
- Modify: `HabitTable/HabitBoardView.swift`
- Modify: `.github/workflows/ios.yml` (스크린샷 반복문)
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `dayCompleteToast(isPresented:autoDismiss:)`, `HabitProgress.isScheduled(_:on:calendar:)`
- Produces: 실행 인자 `-previewDayComplete`(샘플의 오늘을 100%로 채우고 토스트를 띄워 둠), 스크린샷 `complete-light.png`, `complete-dark.png`

- [ ] **Step 1: 샘플 데이터에 "오늘 다 함" 옵션** — `HabitTableApp.swift`에서 `SampleData.insert`의 시그니처와 오늘 처리 부분을 바꾼다.

바꾸기 전:
```swift
    static func insert(into context: ModelContext, today: Date = .now) {
```
바꾼 뒤:
```swift
    static func insert(into context: ModelContext, today: Date = .now, completeToday: Bool = false) {
```
`habits[0].completedDays.append(DayKey.make(today, calendar: cal))` 줄 바로 아래에:
```swift
        // 스크린샷용: 오늘 해야 하는 요일 습관을 모두 채워 하루 완성(꽃·토스트) 모습을 만든다
        if completeToday {
            let todayKey = DayKey.make(today, calendar: cal)
            for habit in habits
            where HabitProgress.isScheduled(habit, on: today, calendar: cal)
                && !habit.completedDays.contains(todayKey) {
                habit.completedDays.append(todayKey)
            }
        }
```
앱 init의 `SampleData.insert(into: container.mainContext)`를 다음으로 바꾼다:
```swift
            SampleData.insert(
                into: container.mainContext,
                completeToday: ProcessInfo.processInfo.arguments.contains("-previewDayComplete")
            )
```

- [ ] **Step 2: 토스트를 띄워 두기** — `HabitBoardView`에서 Task 5 Step 3의 줄을 바꾼다.

```swift
        .dayCompleteToast(isPresented: $showDayComplete, autoDismiss: !Self.holdsDayCompleteToast)
```
`private let calendar = AppCalendar.make()` 아래에:
```swift
    /// 스크린샷 확인용: "-previewDayComplete" 인자로 실행하면 하루 완성 토스트를 띄워 둔다
    private static let holdsDayCompleteToast =
        ProcessInfo.processInfo.arguments.contains("-previewDayComplete")
```
기존 `.task { rescheduleReminders() }`를 다음으로 바꾼다:
```swift
        .task {
            rescheduleReminders()
            if Self.holdsDayCompleteToast { showDayComplete = true }
        }
```

- [ ] **Step 3: CI 스크린샷 추가** — `.github/workflows/ios.yml`의 `for MODE in light dark; do` 반복문 안, `todo-$MODE.png` 찍고 `terminate`한 줄 아래, `done` 위에:

```yaml
            xcrun simctl launch "$UDID" "$BUNDLE" -seedSampleData -previewDayComplete
            sleep 6
            xcrun simctl io "$UDID" screenshot "screenshots/complete-$MODE.png"
            xcrun simctl terminate "$UDID" "$BUNDLE" || true
```

- [ ] **Step 4: `CLAUDE.md` 갱신**
  - "구조"에 추가:
    ```
      CheckCell.swift            체크 칸 + 체크 효과(칸 튐·체크 그리기·잎 세 장)
      BloomMark.swift            하루 완성 꽃 그림(꽃잎 다섯 장, 피는 움직임)
      DayCompleteToast.swift     하루 완성 토스트 + .dayCompleteToast 수정자
      Motion.swift               움직임 수치(시간·곡선) 모음
    ```
    `WeekMatrixView.swift` 설명에서 "CheckCell"을 빼고, `LawnView.swift` 설명에 "오늘 100%면 꽃"을 더한다.
  - "규칙"에 추가:
    `- 하루 완성 = 잔디 100%(HabitProgress.isDayComplete). 오늘 100%인 동안 잔디 오늘 칸에 꽃. 토스트는 오늘 칸 체크로 처음 완성될 때만, 하루 한 번(@AppStorage "lastCelebratedDay"). 움직임 수치는 Motion에만 둔다. 체크 해제·동작 줄이기는 움직임 없음.`
  - 스크린샷 실행 인자 줄에 `-previewDayComplete`(오늘 100% + 토스트 고정)와 `complete-light/dark.png`를 더한다.
  - "진행 상황"의 완료 목록에 "체크 효과, 하루 완성(꽃·토스트)"을 더하고, 실기기 확인 필요에 "체크 효과 연타, 토스트 VoiceOver 알림"을 더한다.

- [ ] **Step 5: 커밋하고 스크린샷 확인**

```bash
git add HabitTable/HabitTableApp.swift HabitTable/HabitBoardView.swift .github/workflows/ios.yml CLAUDE.md
git commit -m "하루 완성 스크린샷(-previewDayComplete) 추가, CLAUDE.md 갱신"
git push
gh run watch
gh run download -n screenshots
```
Expected: `complete-light.png`, `complete-dark.png`가 생긴다. 확인할 것(춘수가 캔버스 `Motion.dc.html` 오른쪽 화면과 나란히 놓고 본다):
  - 잔디 오늘 칸 오른쪽 아래에 꽃(분홍 꽃잎 다섯 장 + 노란 가운데), 날짜 숫자와 겹쳐 읽기 어렵지 않은지.
  - 토스트가 탭 바 바로 위 12pt, 좌우 16pt, 모서리 18. 라이트는 어두운 바탕 + 흰 글자, 다크는 밝은 바탕 + 어두운 글자.
  - 이번 주 표의 오늘 열이 모두 체크(새 체크 선 모양).
  어긋나면 수치를 고쳐 다시 push한다.

---

## 넘기는 순서

춘수(이 계획) → 구현(실행 방식은 사용자가 고름) → 춘봉이(리뷰, Review Focus 1·5는 실기기/시뮬레이터 수동 확인) → 춘배(다크 토스트 색 확인).
