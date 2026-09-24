import AppKit
import BuildkiteNotchCore
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    /// UNUserNotificationCenter crashes outside an app bundle (e.g. `swift run`).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func setUp() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(_ event: BuildEvent, pipelineName: String) {
        guard let center else { return }
        let build = event.build
        let content = UNMutableNotificationContent()
        content.title = "\(pipelineName) #\(build.number) — \(Self.label(for: event.kind))"
        content.body = [build.title, build.branch.map { "⎇ \($0)" }]
            .compactMap { $0 }
            .joined(separator: "\n")
        content.userInfo = ["url": build.webUrl]
        if event.kind == .failed || event.kind == .blocked { content.sound = .default }

        center.add(UNNotificationRequest(identifier: "\(build.id)-\(build.state.rawValue)", content: content, trigger: nil))
    }

    private static func label(for kind: BuildEventKind) -> String {
        switch kind {
        case .passed: "✅ Passou"
        case .failed: "❌ Falhou"
        case .blocked: "⏸ Aguardando aprovação"
        case .canceled: "⛔️ Cancelado"
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
