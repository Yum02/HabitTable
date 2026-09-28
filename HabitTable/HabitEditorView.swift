import SwiftUI
import SwiftData

/// 습관 추가·수정 시트
struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil이면 새 습관
    let habit: Habit?
    let calendar: Calendar
    let nextSortOrder: Int

    @State private var name: String
    @State private var weekdays: Set<Int>
    @FocusState private var nameFocused: Bool

    init(habit: Habit?, calendar: Calendar, nextSortOrder: Int) {
        self.habit = habit
        self.calendar = calendar
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: habit?.name ?? "")
        _weekdays = State(initialValue: Set(habit?.weekdays ?? Array(1...7)))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !weekdays.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section(title: "이름") {
                        TextField("예: 물 2L 마시기", text: $name)
                            .font(.spoqa(17, .regular, relativeTo: .body))
                            .foregroundStyle(Theme.soil)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                    }

                    section(title: "반복 요일", trailing: {
                        Button("매일") { weekdays = Set(1...7) }
                            .font(.spoqa(13, .bold, relativeTo: .footnote))
                            .foregroundStyle(Theme.grass4)
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
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
                .padding(16)
            }
            .background(Theme.meadow.ignoresSafeArea())
            .navigationTitle(habit == nil ? "새 습관" : "습관 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(Theme.stem)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .font(.spoqa(17, .bold, relativeTo: .body))
                        .disabled(!canSave)
                }
            }
            .onAppear { if habit == nil { nameFocused = true } }
        }
        .tint(Theme.grass4)
        .presentationDetents([.medium, .large])
    }

    private func section<Content: View, Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.spoqa(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(Theme.stem)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 4)
            content()
        }
    }

    private func save() {
        guard canSave else { return }
        let days = weekdays.sorted()
        if let habit {
            habit.name = trimmedName
            habit.weekdays = days
        } else {
            context.insert(Habit(
                name: trimmedName,
                weekdays: days,
                createdDay: DayKey.make(.now, calendar: calendar),
                sortOrder: nextSortOrder
            ))
        }
        dismiss()
    }
}

/// 월~일 요일 버튼 7개
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    /// 표시 순서: 월(2) … 토(7), 일(1)
    private let order = [2, 3, 4, 5, 6, 7, 1]
    private let names = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(names[day - 1])
                        .font(.spoqa(15, .bold, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(isOn ? Color.white : dayColor(day))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn ? Theme.grass3 : Theme.grass0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(names[day - 1])요일")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func dayColor(_ day: Int) -> Color {
        day == 1 ? Theme.sunday : day == 7 ? Theme.saturday : Theme.soil
    }
}

#Preview {
    HabitEditorView(habit: nil, calendar: AppCalendar.make(), nextSortOrder: 0)
        .modelContainer(for: [Habit.self, TodoItem.self], inMemory: true)
}
