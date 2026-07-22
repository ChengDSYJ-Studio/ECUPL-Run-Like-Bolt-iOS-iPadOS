import Foundation
import UserNotifications

enum StartReminder {
    static func schedule(for configuration: TrackConfiguration) async throws {
        guard let date = configuration.scheduledStart, date > Date() else { throw ReminderError.futureDateRequired }
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw ReminderError.permissionDenied }
        let content = UNMutableNotificationContent()
        content.title = "Run Like Bolt Lab：路线已到开始时间"
        content.body = "\(configuration.name) · \(configuration.laps) 圈 · \(configuration.speedMetersPerSecond, specifier: \"%.1f\") 米/秒。请在 Xcode 测试计划中选择导出的 GPX。"
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: "ecupl.runLikeBolt.start", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        try await center.add(request)
    }

    enum ReminderError: LocalizedError { case futureDateRequired, permissionDenied
        var errorDescription: String? { switch self { case .futureDateRequired: return "请选择未来的开始时间"; case .permissionDenied: return "未获通知权限，无法安排提醒" } }
    }
}
