# Habit Table (iOS · SwiftUI)

iOS 17 이상 · Swift · SwiftUI · SwiftData

## 화면
- **이번 주 습관 표**: 줄 = 습관, 칸 = 월~일. 칸을 누르면 체크/해제 (오늘까지만)
- **최근 4주 잔디**: 월요일 시작 7칸 × 4줄, 달성률에 따라 6단계 초록
- **＋**: 습관 추가 (이름, 반복 요일) / 습관 이름 길게 누르기: 수정·삭제
- 글꼴: 스포카 한 산스 Neo (SIL OFL 1.1, `SpoqaHanSansNeo-OFL.txt`)

## 폴더 구성
```
HabitTable/
├─ .github/workflows/ios.yml   ← 클라우드 Mac 빌드·테스트·스크린샷
├─ project.yml                 ← Xcode 프로젝트 설정 (XcodeGen)
├─ HabitTable/
│  ├─ HabitTableApp.swift      ← 앱 시작, 저장소, 샘플 데이터
│  ├─ ContentView.swift
│  ├─ HabitBoardView.swift     ← 메인 화면
│  ├─ WeekMatrixView.swift     ← 이번 주 습관 표
│  ├─ LawnView.swift           ← 최근 4주 잔디
│  ├─ HabitEditorView.swift    ← 추가·수정 시트
│  ├─ Habit.swift              ← 데이터 모델
│  ├─ HabitProgress.swift      ← 계산 규칙 (테스트 대상)
│  ├─ Theme.swift              ← 색·글꼴
│  └─ SpoqaHanSansNeo-*.ttf
└─ HabitTableTests/
   └─ HabitProgressTests.swift
```

## Windows에서 확인하기
GitHub에 push하면 Actions가 클라우드 Mac에서 빌드 → 테스트 → iPhone 시뮬레이터 스크린샷을 만듭니다.

```powershell
git add -A
git commit -m "변경 내용"
git push

gh run watch                    # 빌드 진행 보기
gh run view --log-failed        # 실패했을 때 로그
gh run download -n screenshots  # 스크린샷 받기
```

## Mac에서 직접 열 때
```
brew install xcodegen
xcodegen generate
open HabitTable.xcodeproj
```
