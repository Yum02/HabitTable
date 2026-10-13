# 하루 완성 효과 — 규칙

시안: 춘배 캔버스 "움직임 시안" 보드(https://claude.ai/artifact/S6aQnV8dU9RbRNJGtKXGeP, 참고용).
이 문서는 **언제·무엇이** 보이는지 정한다. 모양과 움직임은 춘배가 다시 그린다.

## 사용자 확정 (2026-10-09)

1. **완성 기준 = 잔디 100%와 같다.** `progress(habits, on: 오늘)`이 `total > 0 && done >= total`
   (`level == .full`). 그날 셈에 들어간 습관이 주 n회 하나뿐이어도(체크한 날만 셈에 들어감)
   완성이다. 잔디 색과 효과가 어긋나지 않게 하려는 것이다.
2. **토스트는 오늘만, 하루 한 번.** 사용자가 **오늘 칸을 체크해서** 오늘이 처음 완성될 때만 띄운다.
   - 지난 날짜를 체크해 그날이 100%가 돼도 띄우지 않는다.
   - 같은 날 해제했다가 다시 채워도 다시 띄우지 않는다. 마지막으로 축하한 날을
     `@AppStorage("lastCelebratedDay")`(DayKey 정수)에 저장해 비교한다.
   - 앱을 켰을 때 이미 100%인 상태는 축하하지 않는다(체크 동작에서만 판단).
3. **잔디 표시는 오늘 칸만.** 오늘이 100%인 동안만 오늘 칸에 보인다. 해제해서 100%가 깨지면
   사라진다. 지난 100%인 날은 지금처럼 가장 진한 초록만으로 표시한다.
4. **모양은 꽃.** 연속 기록 배지 🌱(이어 가기)와 뜻을 나누기 위해 하루 완성은 **꽃이 핀다**.
   토스트 문구: "오늘 습관을 모두 해냈어요" / "잔디에 꽃이 피었어요".

## 기획에서 정한 것 (사용자 확인 필요 없음)

- **토스트 위치**: 탭 바 위에 띄워 탭 바를 가리지 않는다. 3초 뒤 사라지고, 누르면 바로 닫힌다.
- **VoiceOver**: 토스트가 뜰 때 `AccessibilityNotification.Announcement("오늘 습관을 모두 해냈어요")`로
  읽어 준다. 잔디 오늘 칸의 접근성 라벨에 "꽃이 피었어요"를 덧붙인다.
- **동작 줄이기**(`accessibilityReduceMotion`): 꽃이 자라는 움직임 없이 바로 나타나고, 토스트는
  미끄러지지 않고 나타났다 사라진다.
- 꽃 색은 `Theme` 토큰으로 정한다(다크 모드 대응). 필요하면 춘배가 토큰을 새로 제안한다.

## 계산 (`HabitProgress`, 테스트 대상)

```swift
/// 잔디 100%와 같은 기준
static func isDayComplete(_ p: DayProgress) -> Bool { p.total > 0 && p.done >= p.total }

/// 체크 동작 직후 토스트를 띄울지
static func shouldCelebrate(before: DayProgress, after: DayProgress,
                            dayKey: Int, todayKey: Int, lastCelebrated: Int) -> Bool {
    dayKey == todayKey && !isDayComplete(before) && isDayComplete(after) && lastCelebrated != todayKey
}
```

테스트: 처음 완성 → true / 이미 완성 상태에서 더 체크 → false / 지난 날짜 → false /
오늘 이미 축하함 → false / 습관 없는 날(0/0) → false / 주 n회 하나만 체크해 1/1 → true.

## 넘기는 순서

춘배(시안: 꽃, 토스트 문구) → 춘식이(구현) → 춘봉이(리뷰·CI).
