import UserNotifications

final class UpdateNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UpdateNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private var actions: [String: () -> Void] = [:]
    private var isConfigured = false

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(title: String, body: String, action: (() -> Void)? = nil) {
        configureIfNeeded()
        LogManager.shared.log("Post notification: \(title)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let identifier = UUID().uuidString
        if let action {
            actions[identifier] = action
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let action = actions.removeValue(forKey: response.notification.request.identifier) {
            DispatchQueue.main.async {
                action()
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
