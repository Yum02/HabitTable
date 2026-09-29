import SwiftUI
import SwiftData

/// 메인 화면: 이번 주 습관 표 + 최근 4주 잔디
struct HabitBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var today = Date.now
    @State private var weekOffset = 0
    @State private var editorTarget: EditorTarget<Habit>?
    @State private var habitToDelete: Habit?
    @State private var showReminderSettings = false
    @State private var rescheduleTask: Task<Void, Never>?
    @AppStorage(ReminderSettings.enabledKey) private var reminderEnabled = false
    @AppStorage(ReminderSettings.minutesKey) private var reminderMinutes = ReminderSettings.defaultMinutes

    private let calendar = AppCalendar.make()

    private var displayedDate: Date {
        calendar.date(byAdding: .day, value: 7 * weekOffset, to: today) ?? today
    }

    private var week: [Date] {
        HabitProgress.weekDates(containing: displayedDate, calendar: calendar)
    }

    /// 알림 예약에 영향을 주는 값만 모은 지문. 이게 바뀌면 다시 예약한다.
    /// (체크/해제, 습관 추가·수정·삭제 모두 여기 반영된다)
    private var reminderSignature: [String] {
        habits.map { "\($0.createdDay)|\($0.weekdays)|\($0.completedDays)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if habits.isEmpty {
                    emptyCard
                } else {
                    WeekMatrixView(
                        habits: habits,
                        week: week,
                        today: today,
                        calendar: calendar,
                        onToggle: toggle,
                        onEdit: { editorTarget = .edit($0) },
                        onDelete: { habitToDelete = $0 }
                    )
                }

                LawnView(habits: habits, today: today, calendar: calendar)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showReminderSettings = true
                } label: {
                    Image(systemName: reminderEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("알림 설정")

                Button {
                    editorTarget = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("습관 추가")
            }
        }
        .sheet(item: $editorTarget) { target in
            HabitEditorView(
                habit: target.model,
                calendar: calendar,
                nextSortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1
            )
        }
        .sheet(isPresented: $showReminderSettings) {
            ReminderSettingsView()
        }
        .confirmationDialog(
            "'\(habitToDelete?.name ?? "")' 습관을 삭제할까요?",
            isPresented: Binding(
                get: { habitToDelete != nil },
                set: { if !$0 { habitToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let habit = habitToDelete { context.delete(habit) }
                habitToDelete = nil
            }
        } message: {
            Text("지금까지의 체크 기록도 함께 지워져요.")
        }
        // 앱을 다시 열었을 때 날짜가 바뀌었으면 '오늘'을 갱신하고 이번 주로 돌아온다
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = .now
                weekOffset = 0
                rescheduleReminders()
            }
        }
        // 첫 진입, 그리고 알림에 영향을 주는 값이 바뀔 때마다 알림을 다시 예약한다
        .task { rescheduleReminders() }
        .onChange(of: reminderSignature) { _, _ in rescheduleReminders() }
        .onChange(of: reminderEnabled) { _, _ in rescheduleReminders() }
        .onChange(of: reminderMinutes) { _, _ in rescheduleReminders() }
    }

    // MARK: - 머리글

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(rangeText)
                    .font(.spoqa(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(Theme.stem)
                    .monospacedDigit()
                Text(weekTitle)
                    .font(.spoqa(26, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.soil)
            }
            Spacer()
            HStack(spacing: 4) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.soil)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("지난주")

                Button {
                    withAnimation(.snappy(duration: 0.2)) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(weekOffset >= 0 ? Theme.stem.opacity(0.35) : Theme.soil)
                        .frame(width: 32, height: 32)
                }
                .disabled(weekOffset >= 0)
                .accessibilityLabel("다음 주")
            }
        }
        .padding(.top, 4)
    }

    private var weekTitle: String {
        switch weekOffset {
        case 0: return "이번 주"
        case -1: return "지난주"
        case ..<(-1): return "\(-weekOffset)주 전"
        default: return "이번 주"
        }
    }

    private var rangeText: String {
        guard let first = week.first, let last = week.last else { return "" }
        func md(_ d: Date) -> String {
            "\(calendar.component(.month, from: d)).\(calendar.component(.day, from: d))"
        }
        return "\(md(first)) – \(md(last))"
    }

    // MARK: - 습관이 없을 때

    private var emptyCard: some View {
        EmptyStateCard(
            title: "첫 습관을 심어 보세요",
            message: "매일 또는 원하는 요일에 할 습관을 추가하면, 이번 주 표와 잔디가 채워지기 시작해요.",
            buttonLabel: "습관 추가"
        ) {
            editorTarget = .new
        }
    }

    // MARK: - 동작

    private func toggle(_ habit: Habit, _ date: Date) {
        guard HabitProgress.canToggle(date: date, today: today, calendar: calendar) else { return }
        let key = DayKey.make(date, calendar: calendar)
        withAnimation(.snappy(duration: 0.2)) {
            habit.completedDays = HabitProgress.toggled(habit.completedDays, key: key)
        }
    }

    /// 알림을 다시 예약한다. 이전 예약 작업이 남아 있으면 취소하고, 그 작업이 끝난 뒤에 새로 시작한다.
    private func rescheduleReminders() {
        let previous = rescheduleTask
        previous?.cancel()
        let enabled = reminderEnabled
        let (hour, minute) = ReminderPlanner.hourMinute(fromMinutes: reminderMinutes)
        let days = ReminderPlanner.plannedDays(habits: habits, now: .now, hour: hour, minute: minute, calendar: calendar)
        let cal = calendar
        rescheduleTask = Task {
            await previous?.value
            await ReminderScheduler.apply(enabled: enabled, dayKeys: days, hour: hour, minute: minute, calendar: cal)
        }
    }
}

#Preview {
    NavigationStack {
        HabitBoardView()
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.light)
}

@MainActor
private let previewContainer: ModelContainer = {
    FontRegistrar.registerBundledFonts()
    let container = try! ModelContainer(for: Habit.self, TodoItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SampleData.insert(into: container.mainContext)
    return container
}()
