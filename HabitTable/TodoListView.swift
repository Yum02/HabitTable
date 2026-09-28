import SwiftUI
import SwiftData

/// 할 일 탭: 고른 날짜의 할 일. 미완료가 위, 완료(줄그음)가 아래
struct TodoListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var todos: [TodoItem]

    @State private var today = Date.now
    @State private var selectedDate = Date.now
    @State private var showDatePicker = false
    @State private var editorTarget: EditorTarget<TodoItem>?

    private let calendar = AppCalendar.make()

    private var selectedKey: Int {
        DayKey.make(selectedDate, calendar: calendar)
    }

    private var isToday: Bool {
        selectedKey == DayKey.make(today, calendar: calendar)
    }

    /// 고른 날짜의 할 일 (미완료 위 → 완료 아래, 각각 만든 순서)
    private var dayTodos: [TodoItem] {
        TodoProgress.items(on: selectedKey, from: todos)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if dayTodos.isEmpty {
                emptyCard
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                .accessibilityLabel("할 일 추가")
            }
        }
        .sheet(item: $editorTarget) { target in
            TodoEditorView(todo: target.model, defaultDate: selectedDate, calendar: calendar)
        }
        .sheet(isPresented: $showDatePicker) {
            TodoDatePickerSheet(date: $selectedDate, calendar: calendar) {
                selectedDate = .now
            }
        }
        // 앱을 다시 열었을 때 날짜가 바뀌었으면 '오늘'을 갱신하고 오늘 목록으로 돌아온다
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = .now
                selectedDate = .now
            }
        }
    }

    // MARK: - 머리글 (날짜 이동)

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                showDatePicker = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("할 일")
                        .font(.spoqa(13, .bold, relativeTo: .footnote))
                        .foregroundStyle(Theme.stem)
                    HStack(spacing: 6) {
                        Text(TodoProgress.dayTitle(for: selectedDate, today: today, calendar: calendar))
                            .font(.spoqa(26, .bold, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.soil)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.stem)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("날짜 선택")

            Spacer()

            if !isToday {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedDate = today }
                } label: {
                    Text("오늘")
                        .font(.spoqa(13, .bold, relativeTo: .footnote))
                        .foregroundStyle(Theme.grass4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.grass0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("오늘로 이동")
            }

            HStack(spacing: 4) {
                Button {
                    shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.soil)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("전날")

                Button {
                    shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.soil)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("다음 날")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func shift(by days: Int) {
        withAnimation(.snappy(duration: 0.2)) {
            selectedDate = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        }
    }

    // MARK: - 목록

    private var list: some View {
        List {
            ForEach(dayTodos) { todo in
                row(todo)
                    .listRowBackground(Theme.card)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("수정") { editorTarget = .edit(todo) }
                            .tint(Theme.grass3)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("삭제", role: .destructive) {
                            withAnimation(.snappy(duration: 0.25)) { context.delete(todo) }
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ todo: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { todo.isDone.toggle() }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(todo.isDone ? Theme.grass3 : Theme.grass2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "완료 취소" : "완료로 표시")

            Text(todo.title)
                .font(.spoqa(16, .medium, relativeTo: .body))
                .foregroundStyle(todo.isDone ? Theme.stem : Theme.soil)
                .strikethrough(todo.isDone, color: Theme.stem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 할 일이 없을 때

    private var emptyCard: some View {
        EmptyStateCard(
            title: isToday ? "오늘 할 일을 추가해 보세요" : "이 날은 할 일이 없어요",
            message: isToday
                ? "병원 예약, 택배 찾기처럼 하루짜리 일을 적어 두세요. 위의 날짜를 눌러 다른 날 할 일도 볼 수 있어요."
                : "아래 버튼으로 이 날 할 일을 미리 적어 둘 수 있어요.",
            buttonLabel: "할 일 추가"
        ) {
            editorTarget = .new
        }
    }
}

/// 날짜를 달력에서 골라 점프하는 시트. 날짜를 탭하면 바로 닫힌다.
private struct TodoDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var date: Date
    let calendar: Calendar
    let onToday: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker("날짜", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.calendar, calendar)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Theme.meadow.ignoresSafeArea())
                .navigationTitle("날짜 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("오늘") {
                            onToday()
                            dismiss()
                        }
                        .foregroundStyle(Theme.grass4)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("닫기") { dismiss() }
                            .foregroundStyle(Theme.stem)
                    }
                }
                .onChange(of: date) { _, _ in dismiss() }
        }
        .tint(Theme.grass4)
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        TodoListView()
    }
    .modelContainer(todoPreviewContainer)
    .preferredColorScheme(.light)
}

@MainActor
private let todoPreviewContainer: ModelContainer = {
    FontRegistrar.registerBundledFonts()
    let container = try! ModelContainer(for: TodoItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let now = Date.now
    let key = DayKey.make(now, calendar: AppCalendar.make())
    container.mainContext.insert(TodoItem(title: "병원 예약 전화하기", day: key, createdAt: now))
    container.mainContext.insert(TodoItem(title: "택배 찾기", day: key, isDone: true, createdAt: now.addingTimeInterval(60)))
    return container
}()
