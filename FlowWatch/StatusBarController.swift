import SwiftUI
import AppKit
import Combine

final class StatusBarController: NSObject, ObservableObject {
    private let displayModeKey = "statusBarDisplayMode"
    private let maxColorRateKey = "maxColorRateMbps"
    private let lastLaunchTime = Date()
    private let monitor: NetworkUsageMonitor
    private let statusItem: NSStatusItem
    private weak var startTimeMenuItem: NSMenuItem?
    private var maxColorRateMbps: Double {
        get {
            UserDefaults.standard.object(forKey: maxColorRateKey) as? Double ?? 100
        }
        set {
            let clamped = max(0, min(newValue, 100))
            UserDefaults.standard.set(clamped, forKey: maxColorRateKey)
            updateStatusButtonContent()
        }
    }
    private var cancellables = Set<AnyCancellable>()
    private var menu: NSMenu = NSMenu()

    init(monitor: NetworkUsageMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        super.init()
        configureStatusButton()
        bindMonitor()
        bindUserDefaults()
        bindNotifications()
        updateStatusButtonContent()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        rebuildMenu()
        statusItem.menu = menu
        button.imagePosition = .imageOnly
        button.focusRingType = .none
    }

    private func bindMonitor() {
        monitor.$downloadBps
            .combineLatest(monitor.$uploadBps, monitor.$todayDownloaded, monitor.$todayUploaded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
                self?.updateStatusButtonContent()
            }
            .store(in: &cancellables)
    }

    private func bindUserDefaults() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusButtonContent()
                self?.refreshStartTimeTitle()
            }
            .store(in: &cancellables)
    }

    private func bindNotifications() {
        NotificationCenter.default.publisher(for: .flowWatchResetToday)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performResetToday()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .flowWatchResetAllHistory)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performResetAllHistory()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .flowWatchLanguageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func updateStatusButtonContent() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .imageOnly

        switch displayMode {
        case .speed:
            renderSpeedOnly(into: button)
        case .total:
            renderTotalOnly(into: button)
        case .both:
            renderCombined(into: button)
        }
    }

    private func colorForSpeed(_ bytesPerSecond: Double) -> NSColor {
        let mbps = max(0, bytesPerSecond) * 8 / 1_000_000
        let maxRate = max(0, maxColorRateMbps)
        guard maxRate > 0 else {
            return normalizedColor(.white)
        }
        let ratio = max(0, min(mbps / maxRate, 1))

        let start = normalizedColor(.white)
        let mid = normalizedColor(.systemYellow)
        let end = normalizedColor(.systemRed)

        if ratio < 0.5 {
            return interpolateColor(from: start, to: mid, t: ratio / 0.5)
        } else {
            return interpolateColor(from: mid, to: end, t: (ratio - 0.5) / 0.5)
        }
    }

    private func normalizedColor(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? color
    }

    private func interpolateColor(from start: NSColor, to end: NSColor, t: Double) -> NSColor {
        let clampedT = CGFloat(max(0, min(1, t)))
        let startColor = normalizedColor(start)
        let endColor = normalizedColor(end)

        let red = startColor.redComponent + (endColor.redComponent - startColor.redComponent) * clampedT
        let green = startColor.greenComponent + (endColor.greenComponent - startColor.greenComponent) * clampedT
        let blue = startColor.blueComponent + (endColor.blueComponent - startColor.blueComponent) * clampedT
        let alpha = startColor.alphaComponent + (endColor.alphaComponent - startColor.alphaComponent) * clampedT

        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func makeSpeedBadgeImage() -> NSImage? {
        let up = monitor.fixedWidthCompactSpeed(monitor.uploadBps)
        let down = monitor.fixedWidthCompactSpeed(monitor.downloadBps)
        let upLine = "\(up)↑"
        let downLine = "\(down)↓"
        let text = "\(upLine)\n\(downLine)"

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = -3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold),
            .paragraphStyle: paragraph
        ]

        let attr = NSMutableAttributedString(string: text, attributes: attributes)
        let upLength = (upLine as NSString).length
        let downLength = (downLine as NSString).length
        attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.uploadBps), range: NSRange(location: 0, length: upLength))
        attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.downloadBps), range: NSRange(location: upLength + 1, length: downLength))

        let size = attr.size()
        let canvas = NSImage(size: NSSize(width: max(42, size.width), height: max(13, size.height)))

        canvas.lockFocus()
        attr.draw(at: NSPoint(
            x: (canvas.size.width - size.width) / 2,
            y: (canvas.size.height - size.height) / 2
        ))
        canvas.unlockFocus()
        canvas.isTemplate = false
        return canvas
    }

    private func makeTotalBadgeImage() -> NSImage? {
        let up = monitor.fixedWidthDataAmount(monitor.todayUploaded)
        let down = monitor.fixedWidthDataAmount(monitor.todayDownloaded)
        let upLine = "\(up)↑"
        let downLine = "\(down)↓"
        let text = "\(upLine)\n\(downLine)"

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = -3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold),
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.white
        ]

        let attr = NSMutableAttributedString(string: text, attributes: attributes)
        let upLength = (upLine as NSString).length
        let downLength = (downLine as NSString).length
        attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.uploadBps), range: NSRange(location: 0, length: upLength))
        attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.downloadBps), range: NSRange(location: upLength + 1, length: downLength))
        let size = attr.size()
        let canvas = NSImage(size: NSSize(width: max(46, size.width), height: max(14, size.height)))

        canvas.lockFocus()
        attr.draw(at: NSPoint(
            x: (canvas.size.width - size.width) / 2,
            y: (canvas.size.height - size.height) / 2
        ))
        canvas.unlockFocus()
        canvas.isTemplate = false
        return canvas
    }

    private func makeCombinedBadgeImage() -> NSImage? {
        let totalsUp = monitor.fixedWidthDataAmount(monitor.todayUploaded) + "↑"
        let totalsDown = monitor.fixedWidthDataAmount(monitor.todayDownloaded) + "↓"
        let speedUp = monitor.fixedWidthCompactSpeed(monitor.uploadBps) + "↑"
        let speedDown = monitor.fixedWidthCompactSpeed(monitor.downloadBps) + "↓"

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = -3
        let font = NSFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold)

        let totalsText = "\(totalsUp)\n\(totalsDown)"
        let totalsAttr = NSMutableAttributedString(
            string: totalsText,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph,
                .foregroundColor: NSColor.white
            ]
        )

        let speedText = "\(speedUp)\n\(speedDown)"
        let speedAttr = NSMutableAttributedString(
            string: speedText,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph
            ]
        )
        let upLength = (speedUp as NSString).length
        speedAttr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.uploadBps), range: NSRange(location: 0, length: upLength))
        speedAttr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.downloadBps), range: NSRange(location: upLength + 1, length: (speedDown as NSString).length))

        let spacer: CGFloat = 6
        let totalSize = totalsAttr.size()
        let speedSize = speedAttr.size()
        let canvasSize = NSSize(width: max(52, totalSize.width) + spacer + max(52, speedSize.width),
                                height: max(max(14, totalSize.height), max(14, speedSize.height)))
        let canvas = NSImage(size: canvasSize)
        canvas.lockFocus()
        totalsAttr.draw(at: NSPoint(
            x: 0,
            y: (canvasSize.height - totalSize.height) / 2
        ))
        speedAttr.draw(at: NSPoint(
            x: max(52, totalSize.width) + spacer,
            y: (canvasSize.height - speedSize.height) / 2
        ))
        canvas.unlockFocus()
        canvas.isTemplate = false
        return canvas
    }

    private func renderSpeedOnly(into button: NSStatusBarButton) {
        if let image = makeSpeedBadgeImage() {
            button.image = image
            button.title = ""
        } else {
            let down = monitor.fixedWidthCompactSpeed(monitor.downloadBps)
            let up = monitor.fixedWidthCompactSpeed(monitor.uploadBps)
            let upLine = "\(up)↑"
            let downLine = "\(down)↓"
            let text = upLine + " " + downLine
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            ]
            let attr = NSMutableAttributedString(string: text, attributes: attributes)
            let upLength = (upLine as NSString).length
            let downLength = (downLine as NSString).length
            attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.uploadBps), range: NSRange(location: 0, length: upLength))
            attr.addAttribute(.foregroundColor, value: colorForSpeed(monitor.downloadBps), range: NSRange(location: upLength + 1, length: downLength))
            button.attributedTitle = attr
        }
    }

    private func renderTotalOnly(into button: NSStatusBarButton) {
        if let image = makeTotalBadgeImage() {
            button.image = image
            button.title = ""
        }
    }

    private func renderCombined(into button: NSStatusBarButton) {
        if let image = makeCombinedBadgeImage() {
            button.image = image
            button.title = ""
        }
    }

    private var displayMode: FlowWatchApp.StatusBarDisplayMode {
        get {
            if let stored = UserDefaults.standard.string(forKey: displayModeKey),
               let mode = FlowWatchApp.StatusBarDisplayMode(rawValue: stored) {
                return mode
            }
            return .speed
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: displayModeKey)
        }
    }

    private func startTimeTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return String(format: LocalizationManager.shared.t("statusbar.lastLaunch"), formatter.string(from: lastLaunchTime))
    }
    
    private func refreshStartTimeTitle() {
        startTimeMenuItem?.title = startTimeTitle()
    }

    private func performResetToday() {
        monitor.resetTodayTraffic()
    }

    private func performResetAllHistory() {
        monitor.clearAllTrafficHistory()
    }

    private func makeDailyTrafficMenuItem() -> NSMenuItem {
        let hostingView = NSHostingView(
            rootView: LocalizedRootView { DailyTrafficView() }
                .environmentObject(LocalizationManager.shared)
        )
        hostingView.layoutSubtreeIfNeeded()
        var size = hostingView.fittingSize
        size.height += 24
        hostingView.frame = NSRect(origin: .zero, size: size)

        let item = NSMenuItem()
        item.view = hostingView
        return item
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("quit.confirm.title")
        alert.informativeText = LocalizationManager.shared.t("quit.confirm.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: LocalizationManager.shared.t("common.cancel"))
        alert.addButton(withTitle: LocalizationManager.shared.t("common.quit"))

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func rebuildMenu() {
        let newMenu = NSMenu()
        let startItem = NSMenuItem(title: startTimeTitle(), action: nil, keyEquivalent: "")
        startItem.isEnabled = false
        startTimeMenuItem = startItem
        newMenu.addItem(startItem)
        newMenu.addItem(makeDailyTrafficMenuItem())
        newMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: LocalizationManager.shared.t("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        newMenu.addItem(settingsItem)
        newMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: LocalizationManager.shared.t("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        newMenu.addItem(quitItem)
        menu = newMenu
        statusItem.menu = menu
    }
}
