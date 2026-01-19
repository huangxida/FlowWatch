import SwiftUI
import AppKit

struct MenuStatusLabel: View {
    @ObservedObject var monitor: NetworkUsageMonitor
    @AppStorage("menuDisplayMode") private var displayModeRaw: String = FlowWatchApp.MenuDisplayMode.icon.rawValue
    @AppStorage("maxColorRateMbps") private var maxColorRateMbps: Double = 100
    @EnvironmentObject private var l10n: LocalizationManager

    private var displayMode: FlowWatchApp.MenuDisplayMode {
        let mode = FlowWatchApp.MenuDisplayMode(storedValue: displayModeRaw)
        if mode.rawValue != displayModeRaw {
            displayModeRaw = mode.rawValue
        }
        return mode
    }

    var body: some View {
        switch displayMode {
        case .icon:
            Label(l10n.t("menuStatus.speed"), systemImage: "speedometer")
        case .compactSpeed:
            let downloadColor = colorForSpeed(monitor.downloadBps)
            let uploadColor = colorForSpeed(monitor.uploadBps)
            if let image = tinyStatusImage(
                down: formattedSpeed(monitor.downloadBps),
                up: formattedSpeed(monitor.uploadBps),
                downColor: downloadColor,
                upColor: uploadColor
            ) {
                Image(nsImage: image)
                    .renderingMode(.original)
            } else {
                VStack(spacing: -2) {
                    Text("↓\(formattedSpeed(monitor.downloadBps))")
                        .foregroundColor(Color(nsColor: downloadColor))
                    Text("↑\(formattedSpeed(monitor.uploadBps))")
                        .foregroundColor(Color(nsColor: uploadColor))
                }
                .font(.system(size: 7, weight: .regular, design: .monospaced))
                .frame(width: 70, alignment: .center)
                .fixedSize()
            }
        }
    }

    private func tinyStatusImage(down: String, up: String, downColor: NSColor, upColor: NSColor) -> NSImage? {
        let downLine = "↓\(down)"
        let upLine = "↑\(up)"
        let text = downLine + "\n" + upLine
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = -2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 7, weight: .regular),
            .paragraphStyle: paragraph
        ]

        let attr = NSMutableAttributedString(string: text, attributes: attributes)
        let downLength = (downLine as NSString).length
        let upLength = (upLine as NSString).length
        attr.addAttribute(.foregroundColor, value: downColor, range: NSRange(location: 0, length: downLength))
        attr.addAttribute(.foregroundColor, value: upColor, range: NSRange(location: downLength + 1, length: upLength))
        let size = attr.size()
        let canvas = NSImage(size: NSSize(width: max(46, size.width), height: max(14, size.height)))

        canvas.lockFocus()
        attr.draw(at: NSPoint(x: (canvas.size.width - size.width) / 2, y: (canvas.size.height - size.height) / 2))
        canvas.unlockFocus()
        return canvas
    }

    private func formattedSpeed(_ bytesPerSecond: Double) -> String {
        let safeBytes = max(0, bytesPerSecond)
        let kb = safeBytes / 1024

        let (value, unit): (Double, String)
        if kb >= 1024 * 1024 {
            value = kb / (1024 * 1024)
            unit = "GB/s"
        } else if kb >= 1024 {
            value = kb / 1024
            unit = "MB/s"
        } else {
            value = kb
            unit = "KB/s"
        }

        let clamped = min(value, 9999.9)
        if unit == "KB/s" {
            return String(format: "%5.0f %@", clamped, unit)
        } else {
            return String(format: "%5.1f %@", clamped, unit)
        }
    }

    private func colorForSpeed(_ bytesPerSecond: Double) -> NSColor {
        let mbps = max(0, bytesPerSecond) * 8 / 1_000_000
        let maxRate = max(0, min(maxColorRateMbps, 100))
        guard maxRate > 0 else {
            return normalizedColor(NSColor.white)
        }
        let ratio = max(0, min(mbps / maxRate, 1))

        let start = normalizedColor(NSColor.white)
        let mid = normalizedColor(NSColor.systemYellow)
        let end = normalizedColor(NSColor.systemRed)

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
}
