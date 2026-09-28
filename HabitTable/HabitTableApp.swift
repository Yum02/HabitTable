import SwiftUI
import SwiftData

@main
struct HabitTableApp: App {
    let container: ModelContainer

    init() {
        FontRegistrar.registerBundledFonts()

        // 스크린샷 확인용: "-seedSampleData" 로 실행하면 메모리에만 샘플을 넣는다 (실제 데이터에 저장되지 않음)
        let useSample = ProcessInfo.processInfo.arguments.contains("-seedSampleData")
        let config = ModelConfiguration(isStoredInMemoryOnly: useSample)
        do {
            container = try ModelContainer(for: Habit.self, TodoItem.self, configurations: config)
        } catch {
            fatalError("저장소를 열 수 없어요: \(error)")
        }
        if useSample {
            SampleData.insert(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // 다크 모드는 추후 작업
                .tint(Theme.grass4)
        }
        .modelContainer(container)
    }
}

/// 미리보기·스크린샷 전용 샘플 데이터
enum SampleData {
    @MainActor
    static func insert(into context: ModelContext, today: Date = .now) {
        let cal = AppCalendar.make()
        guard let start = cal.date(byAdding: .day, value: -45, to: today) else { return }
        let startKey = DayKey.make(start, calendar: cal)

        let habits = [
            Habit(name: "물 2L 마시기", weekdays: Array(1...7), createdDay: startKey, sortOrder: 0),
            Habit(name: "운동 30분", weekdays: [2, 4, 6], createdDay: startKey, sortOrder: 1),
            Habit(name: "독서 20쪽", weekdays: [2, 3, 4, 5, 6], createdDay: startKey, sortOrder: 2),
        ]

        // 지난 45일 동안 들쭉날쭉한 기록 (고정 규칙이라 매번 같은 모양)
        for offset in 1...45 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = DayKey.make(day, calendar: cal)
            for (index, habit) in habits.enumerated()
            where HabitProgress.isScheduled(habit, on: day, calendar: cal) && (offset * 7 + index * 3) % 5 != 0 {
                habit.completedDays.append(key)
            }
        }
        // 오늘은 첫 번째 습관만 완료
        habits[0].completedDays.append(DayKey.make(today, calendar: cal))

        habits.forEach { context.insert($0) }

        // 할 일 탭 스크린샷용: 미완료 3개 + 완료 2개 (생성 시각을 달리해 순서가 고정됨)
        let todos = [
            TodoItem(title: "병원 예약 전화하기", createdAt: today.addingTimeInterval(-500)),
            TodoItem(title: "택배 찾기", isDone: true, createdAt: today.addingTimeInterval(-400)),
            TodoItem(title: "세탁소에 맡긴 코트 찾아오기", createdAt: today.addingTimeInterval(-300)),
            TodoItem(title: "부모님께 전화드리기", isDone: true, createdAt: today.addingTimeInterval(-200)),
            TodoItem(title: "이번 달 관리비 납부하기 — 계좌이체 후 영수증 사진을 찍어 가족 채팅방에 공유하기", createdAt: today.addingTimeInterval(-100)),
        ]
        todos.forEach { context.insert($0) }
    }
}
