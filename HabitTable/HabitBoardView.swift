import SwiftUI
import SwiftData

/// 메인 화면: 이번 주 습관 표 + 최근 4주 잔디
struct HabitBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var today = Date.now
    @State private var editorTarget: EditorTarget?
    @State private var habitToDelete: Habit?

    private let calendar = AppCalendar.make()

    private var week: [Date] {
        HabitProgress.weekDates(containing: today, calendar: calendar)
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
            ToolbarItem(placement: .topBarTrailing) {
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
                habit: target.habit,
                calendar: calendar,
                nextSortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1
            )
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
        // 앱을 다시 열었을 때 날짜가 바뀌었으면 '오늘'을 갱신
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .now }
        }
    }

    // MARK: - 머리글

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rangeText)
                .font(.spoqa(13, .bold, relativeTo: .footnote))
                .foregroundStyle(Theme.stem)
                .monospacedDigit()
            Text("이번 주")
                .font(.spoqa(26, .bold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.soil)
        }
        .padding(.top, 4)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("첫 습관을 심어 보세요")
                .font(.spoqa(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.soil)
            Text("매일 또는 원하는 요일에 할 습관을 추가하면, 이번 주 표와 잔디가 채워지기 시작해요.")
                .font(.spoqa(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Theme.stem)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                editorTarget = .new
            } label: {
                Label("습관 추가", systemImage: "plus")
                    .font(.spoqa(15, .bold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.grass4))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    // MARK: - 동작

    private func toggle(_ habit: Habit, _ date: Date) {
        guard HabitProgress.canToggle(date: date, today: today, calendar: calendar) else { return }
        let key = DayKey.make(date, calendar: calendar)
        withAnimation(.snappy(duration: 0.2)) {
            habit.completedDays = HabitProgress.toggled(habit.completedDays, key: key)
        }
    }
}

/// 시트에 무엇을 띄울지
enum EditorTarget: Identifiable {
    case new
    case edit(Habit)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let habit): return "edit-\(habit.persistentModelID.hashValue)"
        }
    }

    var habit: Habit? {
        if case .edit(let habit) = self { return habit }
        return nil
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
    let container = try! ModelContainer(for: Habit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SampleData.insert(into: container.mainContext)
    return container
}()
