import SwiftUI

/// 이번 주 습관 표: 줄 = 습관, 칸 = 월~일
struct WeekMatrixView: View {
    let habits: [Habit]
    let week: [Date]
    let today: Date
    let calendar: Calendar
    let onToggle: (Habit, Date) -> Void
    let onEdit: (Habit) -> Void
    let onDelete: (Habit) -> Void

    private let nameWidth: CGFloat = 82

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 10) {
            GridRow {
                Color.clear.frame(width: nameWidth, height: 1)
                ForEach(week, id: \.self) { date in
                    DayHeader(date: date, isToday: calendar.isDate(date, inSameDayAs: today), calendar: calendar)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(habits) { habit in
                GridRow {
                    Text(habit.name)
                        .font(.spoqa(12.5, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.soil)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: nameWidth, height: 34, alignment: .leading)
                        .padding(.leading, 4)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button { onEdit(habit) } label: { Label("수정", systemImage: "pencil") }
                            Button(role: .destructive) { onDelete(habit) } label: { Label("삭제", systemImage: "trash") }
                        }
                        .accessibilityHint("길게 누르면 수정하거나 삭제할 수 있어요")

                    ForEach(week, id: \.self) { date in
                        CheckCell(state: state(of: habit, on: date)) {
                            onToggle(habit, date)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(accessibilityLabel(habit, date))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func state(of habit: Habit, on date: Date) -> CheckCell.CellState {
        guard HabitProgress.isScheduled(habit, on: date, calendar: calendar) else { return .rest }
        guard HabitProgress.canToggle(date: date, today: today, calendar: calendar) else { return .future }
        return HabitProgress.isCompleted(habit, on: date, calendar: calendar) ? .done : .missed
    }

    private func accessibilityLabel(_ habit: Habit, _ date: Date) -> String {
        let md = "\(calendar.component(.month, from: date))월 \(calendar.component(.day, from: date))일"
        let status: String
        switch state(of: habit, on: date) {
        case .done: status = "완료"
        case .missed: status = "미완료"
        case .future: status = "아직 안 온 날"
        case .rest: status = "쉬는 날"
        }
        return "\(habit.name), \(md), \(status)"
    }
}

/// 요일 + 날짜 머리글
private struct DayHeader: View {
    let date: Date
    let isToday: Bool
    let calendar: Calendar

    private static let names = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isFirstOfMonth = day == 1

        VStack(spacing: 2) {
            Text(Self.names[weekday - 1])
                .font(.spoqa(10.5, .bold, relativeTo: .caption2))
                .foregroundStyle(Theme.stem)
            Text(isFirstOfMonth ? "\(calendar.component(.month, from: date))/1" : "\(day)")
                .font(.spoqa(isFirstOfMonth ? 11 : 13, .bold, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : (isFirstOfMonth ? Theme.grass4 : Theme.soil))
                .frame(minWidth: 24, minHeight: 18)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.grass4)
                    }
                }
        }
        .padding(.bottom, 2)
    }
}

/// 체크 칸 하나
struct CheckCell: View {
    enum CellState { case done, missed, future, rest }

    let state: CellState
    let action: () -> Void

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
            Button(action: action) {
                shape
                    .fill(state == .done ? Theme.grass3 : Theme.grass0)
                    .frame(width: size, height: size)
                    .overlay {
                        if state == .done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 34, height: 34) // 누르는 영역은 조금 넉넉하게
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: state == .done)
        }
    }
}
