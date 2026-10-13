import Foundation
import UserNotifications

/// 설정 저장 키. HabitBoardView와 ReminderSettingsView가 같은 값을 @AppStorage로 읽는다.
enum ReminderSettings {
    static let enabledKey = "reminderEnabled"
    static let minutesKey = "reminderMinutes"     // 0시부터의 분
    static let defaultMinutes = 21 * 60           // 저녁 9시
}

/// UNUserNotificationCenter를 감싼 얇은 래퍼. 무엇을 예약할지는 ReminderPlanner가 정한다.
enum ReminderScheduler {
    private static let idPrefix = "reminder-"

    /// 알림 권한을 요청한다. 이미 허용돼 있으면 바로 true.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// 현재 iOS 알림 권한 상태 (요청하지 않고 읽기만 한다).
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 기존 예약을 모두 지우고, enabled이면 dayKeys 날짜마다 hour:minute에 알림을 다시 예약한다.
    /// 호출하는 쪽이 이전 호출을 취소할 수 있도록 중간마다 취소를 확인한다.
    static func apply(enabled: Bool, dayKeys: [Int], hour: Int, minute: Int, calendar: Calendar) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        if Task.isCancelled { return }
        let old = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        guard enabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        for key in dayKeys {
            if Task.isCancelled { return }
            guard let date = DayKey.date(key, calendar: calendar) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = "Habit Table"
            content.body = "오늘 체크할 습관이 남아 있어요"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + String(key), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
