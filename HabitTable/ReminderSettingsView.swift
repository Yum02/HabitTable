import SwiftUI

/// 알림 설정 시트: 켜기/끄기 + 시각
struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReminderSettings.enabledKey) private var enabled = false
    @AppStorage(ReminderSettings.minutesKey) private var minutes = ReminderSettings.defaultMinutes
    @State private var showDenied = false

    private let calendar = AppCalendar.make()

    /// 켤 때 권한을 요청하고, 거부되면 스위치를 켜지 않는다.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { enabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await ReminderScheduler.requestAuthorization()
                        enabled = granted
                        showDenied = !granted
                    }
                } else {
                    enabled = false
                    showDenied = false
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let (hour, minute) = ReminderPlanner.hourMinute(fromMinutes: minutes)
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
            },
            set: { minutes = ReminderPlanner.minutes(from: $0, calendar: calendar) }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    Toggle(isOn: enabledBinding) {
                        Text("습관 알림")
                            .font(.spoqa(17, .regular, relativeTo: .body))
                            .foregroundStyle(Theme.soil)
                    }
                    .tint(Theme.grass4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if enabled {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("알림 시각")
                                .font(.spoqa(17, .regular, relativeTo: .body))
                                .foregroundStyle(Theme.soil)
                            Spacer()
                            DatePicker("알림 시각", selection: timeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.calendar, calendar)
                                .environment(\.locale, Locale(identifier: "ko_KR"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))

                Text(showDenied
                     ? "알림이 허용되어 있지 않아요. 설정 앱에서 Habit Table의 알림을 허용해 주세요."
                     : "정한 시각에 그날 체크할 습관이 남아 있을 때만 알려드려요.")
                    .font(.spoqa(13, .regular, relativeTo: .footnote))
                    .foregroundStyle(showDenied ? Theme.sunday : Theme.stem)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.meadow.ignoresSafeArea())
            .navigationTitle("알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(.spoqa(17, .bold, relativeTo: .body))
                }
            }
        }
        .tint(Theme.grass4)
        .presentationDetents([.medium])
    }
}

#Preview {
    ReminderSettingsView()
}
