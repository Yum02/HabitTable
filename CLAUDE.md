# Habit Table — 프로젝트 안내 (Claude Code용)

습관을 요일별로 체크하고 "잔디"로 기록을 보는 iOS 앱.
Swift · SwiftUI · SwiftData, 최소 iOS 17. UI 문구는 모두 한국어(해요체).

## 개발 환경 제약 (중요)
- 개발자는 **Windows**를 쓰고 Mac이 없다. 로컬에서 Xcode 빌드·시뮬레이터 실행이 불가능하다.
- 확인은 **GitHub Actions**로 한다: push → `.github/workflows/ios.yml`이 macOS 러너에서
  XcodeGen으로 프로젝트 생성 → 단위 테스트 → iPhone 시뮬레이터 스크린샷(artifact `screenshots`).
- 결과 확인 (gh CLI):
  - `gh run list --limit 3`
  - `gh run watch` (진행 중 실행 따라가기)
  - `gh run view --log-failed` (실패 로그)
  - `gh run download -n screenshots` (스크린샷 받기)
- 그래서 코드를 바꾸면 **컴파일 가능성을 특히 꼼꼼히 확인**하고, 계산 로직은 테스트로 검증한다.
- `.xcodeproj`는 커밋하지 않는다(`project.yml`에서 생성).

## 구조
```
project.yml                  XcodeGen 설정 (앱 타깃 + 테스트 타깃)
HabitTable/
  HabitTableApp.swift        앱 시작, ModelContainer, 글꼴 등록, SampleData(-seedSampleData)
  ContentView.swift          TabView 루트 (습관 / 할 일 탭)
  HabitBoardView.swift       메인 화면: "이번 주" 습관 표 + 최근 4주 잔디, 추가/수정/삭제
  WeekMatrixView.swift       습관 표 (줄=습관, 칸=월~일), CheckCell
  LawnView.swift             최근 4주 잔디 (월요일 시작 7×4)
  HabitEditorView.swift      추가·수정 시트, WeekdayPicker
  Habit.swift                @Model Habit, HabitSchedulable 프로토콜, DayKey
  TodoItem.swift             @Model TodoItem (하루짜리 할 일, 날짜 day=DayKey, 습관과 독립)
  TodoProgress.swift         할 일 규칙(순수 함수): 정렬, 날짜별 필터, 날짜 제목 ← 테스트 대상
  TodoListView.swift         "할 일" 탭: 날짜 이동(‹ ›·달력), 미완료 위/완료 아래, 스와이프 수정·삭제
  TodoEditorView.swift       할 일 추가·수정 시트 (이름 + 날짜)
  HabitProgress.swift        순수 계산 규칙(AppCalendar, 주/잔디 날짜, 달성률, 색 단계) ← 테스트 대상
  Theme.swift                색 토큰, Font.spoqa(...), FontRegistrar, Color(hex:)
  SpoqaHanSansNeo-*.ttf      글꼴 (SIL OFL, 라이선스 SpoqaHanSansNeo-OFL.txt)
HabitTableTests/
  HabitProgressTests.swift   계산 규칙 단위 테스트
  TodoProgressTests.swift    할 일 정렬·날짜 규칙 테스트
```

## 규칙
- 날짜는 `DayKey`(예: 20260928 정수)로 저장·비교한다. 시간대 문제를 피하기 위함.
- 요일 번호는 Calendar 기준: 일=1, 월=2 … 토=7. 화면 표시는 **월요일 시작**(`AppCalendar.make()`).
- 계산 로직은 `HabitProgress`(순수 함수)에 두고 `HabitProgressTests`에 테스트를 먼저 추가한다.
  테스트는 SwiftData 없이 `HabitSchedulable`을 따르는 가짜 구조체로 작성한다.
- 색은 `Theme`의 토큰만 쓴다. 글꼴은 `.font(.spoqa(크기, .bold, relativeTo: .body))`.
- 체크는 오늘까지만 가능, 습관은 `createdDay` 이후만 계산.
- 할 일은 날짜별 목록이다(`TodoItem.day`, 이월 없음). 습관과 달리 미래 날짜에도 추가·체크할 수 있다.
- 현재 라이트 모드 고정(`.preferredColorScheme(.light)`). 다크 모드는 미구현.
- ModelContainer를 만드는 곳(앱·미리보기)에는 Habit.self와 TodoItem.self를 모두 넣는다. 빠지면 @Query가 런타임에 크래시한다.
- 스크린샷 실행 인자: `-seedSampleData`(샘플 데이터), `-startTodoTab`(시작 탭을 할 일로).

## 확정된 디자인 (사용자 승인)
- 잔디 초록 단계: #E3EBDC → #BFE3A5 → #7FCA6B → #3FA34D → #226F35
- 배경 #EEF5E8 + 아래쪽 풀빛 그라데이션, 글자 #1B2A1E / 보조 #7A8A77
- 메인: "이번 주"(월~일) 표 — 칸 탭으로 체크, 미래 점선, 쉬는 요일 "–"
- 잔디 6단계: 할 습관 없음 / 0% / 1–49 / 50–74 / 75–99 / 100%, 미래 점선
- 2주·1달 보기는 사용자가 원하지 않음(삭제됨)
- 웹 미리보기(디자인 확인용): https://claude.ai/artifact/9evP3YseWcjMbqrw8nkXQj

## 작업 방식
- 사용자는 기능을 **하나씩** 설계 → 승인 → 구현하길 원한다.
- 다음 후보: 알림, 다크 모드.
