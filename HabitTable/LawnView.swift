import SwiftUI

/// 최근 4주 잔디 (월요일 시작, 7칸 × 4줄)
struct LawnView: View {
    let habits: [Habit]
    let today: Date
    let calendar: Calendar

    private let weekdayLabels = ["월", "화", "수", "목", "금", "토", "일"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    private var dates: [Date] {
        HabitProgress.lawnDates(today: today, weeks: 4, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("최근 4주 잔디")
                    .font(.spoqa(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(Theme.stem)
                Spacer()
                percentText
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.spoqa(10.5, .bold, relativeTo: .caption2))
                        .foregroundStyle(index == 5 ? Theme.saturday : index == 6 ? Theme.sunday : Theme.stem)
                }
                ForEach(dates, id: \.self) { date in
                    LawnCell(
                        day: calendar.component(.day, from: date),
                        level: level(on: date),
                        isToday: calendar.isDate(date, inSameDayAs: today)
                    )
                }
            }

            legend
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func level(on date: Date) -> ProgressLevel {
        let progress = HabitProgress.progress(habits, on: date, calendar: calendar)
        return HabitProgress.level(for: progress, date: date, today: today, calendar: calendar)
    }

    @ViewBuilder
    private var percentText: some View {
        if let percent = HabitProgress.averagePercent(habits, dates: dates, today: today, calendar: calendar) {
            (Text("\(percent)").font(.spoqa(26, .bold, relativeTo: .title))
             + Text("%").font(.spoqa(14, .bold, relativeTo: .footnote)))
                .foregroundStyle(Theme.soil)
                .monospacedDigit()
                .accessibilityLabel("평균 달성률 \(percent)퍼센트")
        } else {
            Text("–")
                .font(.spoqa(20, .bold, relativeTo: .title))
                .foregroundStyle(Theme.stem)
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("적게")
            ForEach([Theme.grass0, Theme.grass1, Theme.grass2, Theme.grass3, Theme.grass4], id: \.self) { color in
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 11, height: 11)
            }
            Text("많이")
        }
        .font(.spoqa(10.5, .bold, relativeTo: .caption2))
        .foregroundStyle(Theme.stem)
        .accessibilityHidden(true)
    }
}

private struct LawnCell: View {
    let day: Int
    let level: ProgressLevel
    let isToday: Bool

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 7, style: .continuous) }

    var body: some View {
        Group {
            if level == .future {
                shape.strokeBorder(Theme.dash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else {
                shape.fill(Theme.color(for: level))
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
        .overlay {
            if isToday {
                shape.inset(by: -3).stroke(Theme.soil, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day)일 \(levelDescription)")
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
