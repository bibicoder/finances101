import UserNotifications

enum SubscriptionNotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(for subscription: Subscription) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [subscription.id.uuidString])

        guard subscription.isActive, subscription.notifyDaysBefore > 0 else { return }

        guard let triggerDate = Calendar.current.date(
            byAdding: .day,
            value: -subscription.notifyDaysBefore,
            to: subscription.nextBillingDate
        ), triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming: \(subscription.name)"
        let days = subscription.notifyDaysBefore
        content.body = "\(subscription.name) billing in \(days) day\(days == 1 ? "" : "s")"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: subscription.id.uuidString, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel(for subscription: Subscription) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [subscription.id.uuidString]
        )
    }
}
