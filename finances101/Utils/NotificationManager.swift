import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let enabledKey = "notificationsEnabled"
    private let paymentsKey = "notifyUpcomingPayments"
    private let debtsKey = "notifyDebtDueDates"
    private let subscriptionsKey = "notifySubscriptions"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var notifyPayments: Bool {
        get { defaultTrue(paymentsKey) }
        set { UserDefaults.standard.set(newValue, forKey: paymentsKey) }
    }

    var notifyDebts: Bool {
        get { defaultTrue(debtsKey) }
        set { UserDefaults.standard.set(newValue, forKey: debtsKey) }
    }

    var notifySubscriptions: Bool {
        get { defaultTrue(subscriptionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: subscriptionsKey) }
    }

    private func defaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // iOS keeps at most 64 pending local notifications and silently drops the rest.
    // Collect all candidates first, then schedule only the nearest ones.
    private static let pendingLimit = 60

    private struct PendingNotification {
        let id: String
        let title: String
        let body: String
        let date: Date
    }

    func scheduleAll(expenses: [ExpenseEntry], debts: [Debt], subscriptions: [Subscription]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard isEnabled else { return }

        let now = Date()
        let calendar = Calendar.current
        var candidates: [PendingNotification] = []

        if notifyPayments {
            for expense in expenses where expense.status == .planned && !expense.isDebtPayment {
                guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: expense.dueDate),
                      reminderDate > now else { continue }
                candidates.append(PendingNotification(
                    id: "expense_\(expense.id)",
                    title: "Payment Due Tomorrow",
                    body: "\(expense.title) — due tomorrow",
                    date: reminderDate
                ))
            }
        }

        if notifyDebts {
            for debt in debts where debt.remainingAmount > 0 {
                guard let targetDate = debt.targetDate,
                      let reminderDate = calendar.date(byAdding: .day, value: -1, to: targetDate),
                      reminderDate > now else { continue }
                candidates.append(PendingNotification(
                    id: "debt_\(debt.id)",
                    title: "Debt Target Date Tomorrow",
                    body: "\(debt.creditor) — target payoff date is tomorrow",
                    date: reminderDate
                ))
            }
        }

        if notifySubscriptions {
            for sub in subscriptions where sub.isActive {
                let daysBefore = max(1, sub.notifyDaysBefore)
                guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: sub.nextBillingDate),
                      reminderDate > now else { continue }
                let daysLabel = daysBefore == 1 ? "tomorrow" : "in \(daysBefore) days"
                candidates.append(PendingNotification(
                    id: "sub_\(sub.id)",
                    title: "Subscription Renewing",
                    body: "\(sub.name) renews \(daysLabel)",
                    date: reminderDate
                ))
            }
        }

        for item in candidates.sorted(by: { $0.date < $1.date }).prefix(Self.pendingLimit) {
            schedule(id: item.id, title: item.title, body: item.body, date: item.date)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func schedule(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
