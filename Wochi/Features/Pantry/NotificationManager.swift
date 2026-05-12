import UserNotifications
import Foundation

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        registerCategories()
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            return false
        }
    }

    func scheduleExpiryNotification(for item: PantryItem) {
        guard let expiry = item.expiryDate else { return }
        cancelNotifications(for: item)

        // 3 days before
        let warningDate = expiry.addingTimeInterval(-Double(Constants.Pantry.expiryWarningDays) * 86_400)
        if warningDate > Date() {
            schedule(
                id: "expiry-warn-\(item.id)",
                title: "Läuft bald ab",
                body: "\(item.name) läuft in \(Constants.Pantry.expiryWarningDays) Tagen ab.",
                date: warningDate,
                categoryID: Constants.Notifications.expiryAlert
            )
        }
        // On expiry day
        if expiry > Date() {
            schedule(
                id: "expiry-day-\(item.id)",
                title: "Heute abgelaufen",
                body: "\(item.name) ist heute abgelaufen.",
                date: expiry,
                categoryID: Constants.Notifications.expiryAlert
            )
        }
    }

    func scheduleLowStockNotification(for item: PantryItem) {
        let content = UNMutableNotificationContent()
        content.title = "Fast aufgebraucht"
        content.body = "\(item.name) ist fast aufgebraucht."
        content.categoryIdentifier = Constants.Notifications.lowStockAlert
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "lowstock-\(item.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotifications(for item: PantryItem) {
        let ids = ["expiry-warn-\(item.id)", "expiry-day-\(item.id)", "lowstock-\(item.id)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func registerCategories() {
        let addToList = UNNotificationAction(
            identifier: "add_to_list",
            title: "Zur Liste hinzufügen",
            options: [.foreground]
        )
        let lowStockCategory = UNNotificationCategory(
            identifier: Constants.Notifications.lowStockAlert,
            actions: [addToList],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([lowStockCategory])
    }

    private func schedule(id: String, title: String, body: String, date: Date, categoryID: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryID
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
