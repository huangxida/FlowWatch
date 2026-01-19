import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: NetworkUsageMonitor?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let monitor = NetworkUsageMonitor()
        self.monitor = monitor
        self.statusBarController = StatusBarController(monitor: monitor)
        
        // 检查开机自启状态
        LaunchAtLoginManager.shared.checkAndPrompt()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.saveTrafficData()
    }
}

