//
//  UpdateManager.swift
//  FlowWatch
//
//  Created by xida huang on 1/22/26.
//

import AppKit
import Combine
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case updating
        case upToDate
        case updateAvailable(version: String)
        case failed(message: String)
    }

    @Published private(set) var status: UpdateStatus = .idle

    private let installMethod: InstallMethod
    private let lastCheckKey = "update.lastCheckTimestamp"
    private let autoCheckInterval: TimeInterval = 60 * 60 * 24
    private let homebrewFormula = "flowwatch"
    private let appcastURLString = "https://raw.githubusercontent.com/huangxida/FlowWatch/feature/about-update/appcast.xml"

    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif

    init(installMethod: InstallMethod = InstallMethodDetector.detect()) {
        self.installMethod = installMethod
        super.init()
        configureSparkleIfNeeded()
    }

    var canCheckForUpdates: Bool {
        switch installMethod {
        case .homebrew:
            return status != .updating
        case .dmg:
            #if canImport(Sparkle)
            return updaterController?.updater.canCheckForUpdates ?? false
            #else
            return false
            #endif
        }
    }

    func checkForUpdates(userInitiated: Bool) {
        recordLastCheck()
        switch installMethod {
        case .homebrew:
            checkHomebrew(userInitiated: userInitiated)
        case .dmg:
            checkSparkle(userInitiated: userInitiated)
        }
    }

    func checkForUpdatesIfNeeded() {
        guard shouldAutoCheck() else { return }
        checkForUpdates(userInitiated: false)
    }

    private func configureSparkleIfNeeded() {
        guard installMethod == .dmg else { return }
        #if canImport(Sparkle)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        #endif
    }

    private func checkSparkle(userInitiated: Bool) {
        #if canImport(Sparkle)
        guard let updaterController else {
            if userInitiated {
                presentDmgUnavailableAlert()
            }
            return
        }
        if userInitiated {
            updaterController.checkForUpdates(nil)
        } else {
            updaterController.updater.checkForUpdatesInBackground()
        }
        #else
        if userInitiated {
            presentDmgUnavailableAlert()
        }
        #endif
    }

    private func checkHomebrew(userInitiated: Bool) {
        status = .checking
        let currentVersion = AppVersion.shortVersion
        let formula = homebrewFormula
        Task.detached { [weak self] in
            do {
                let latestVersion = try Self.fetchHomebrewVersion(formula: formula)
                let isNewer = Self.compareVersions(latestVersion, currentVersion) == .orderedDescending
                await MainActor.run {
                    guard let self else { return }
                    if isNewer {
                        self.status = .updateAvailable(version: latestVersion)
                        self.presentUpdateAvailableAlert(version: latestVersion)
                    } else {
                        self.status = .upToDate
                        if userInitiated {
                            self.presentUpToDateAlert()
                        }
                        self.status = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = .failed(message: self.message(for: error))
                    if userInitiated {
                        self.presentCheckFailedAlert(message: self.message(for: error))
                    }
                    self.status = .idle
                }
            }
        }
    }

    private func presentUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("update.check.upToDate.title")
        alert.informativeText = LocalizationManager.shared.t("update.check.upToDate.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizationManager.shared.t("common.ok"))
        activateAppAndShow(alert: alert)
    }

    private func presentCheckFailedAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("update.check.failed.title")
        alert.informativeText = String(format: LocalizationManager.shared.t("update.check.failed.message"), message)
        alert.alertStyle = .warning
        alert.addButton(withTitle: LocalizationManager.shared.t("common.ok"))
        activateAppAndShow(alert: alert)
    }

    private func presentUpdateAvailableAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = String(format: LocalizationManager.shared.t("update.available.title"), version)
        alert.informativeText = LocalizationManager.shared.t("update.available.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizationManager.shared.t("update.available.updateNow"))
        alert.addButton(withTitle: LocalizationManager.shared.t("update.available.later"))
        let response = activateAppAndShow(alert: alert)
        if response == .alertFirstButtonReturn {
            performHomebrewUpgrade()
        }
    }

    private func performHomebrewUpgrade() {
        status = .updating
        let formula = homebrewFormula
        Task.detached { [weak self] in
            do {
                _ = try Self.runBrew(arguments: ["upgrade", formula])
                await MainActor.run {
                    guard let self else { return }
                    self.status = .idle
                    self.presentUpgradeSuccessAlert()
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = .idle
                    self.presentUpgradeFailedAlert(message: self.message(for: error))
                }
            }
        }
    }

    private func presentUpgradeSuccessAlert() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("update.upgrade.success.title")
        alert.informativeText = LocalizationManager.shared.t("update.upgrade.success.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizationManager.shared.t("common.ok"))
        activateAppAndShow(alert: alert)
    }

    private func presentUpgradeFailedAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("update.upgrade.failed.title")
        alert.informativeText = String(format: LocalizationManager.shared.t("update.upgrade.failed.message"), message)
        alert.alertStyle = .warning
        alert.addButton(withTitle: LocalizationManager.shared.t("common.ok"))
        activateAppAndShow(alert: alert)
    }

    private func presentDmgUnavailableAlert() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.t("update.check.failed.title")
        alert.informativeText = LocalizationManager.shared.t("update.dmg.unavailable")
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizationManager.shared.t("update.openDownload"))
        alert.addButton(withTitle: LocalizationManager.shared.t("common.cancel"))
        let response = activateAppAndShow(alert: alert)
        if response == .alertFirstButtonReturn,
           let url = URL(string: "https://github.com/huangxida/FlowWatch/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    private func activateAppAndShow(alert: NSAlert) -> NSApplication.ModalResponse {
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    private func recordLastCheck() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
    }

    private func shouldAutoCheck() -> Bool {
        let lastTimestamp = UserDefaults.standard.double(forKey: lastCheckKey)
        if lastTimestamp <= 0 {
            return true
        }
        let lastDate = Date(timeIntervalSince1970: lastTimestamp)
        return Date().timeIntervalSince(lastDate) >= autoCheckInterval
    }

    private func message(for error: Error) -> String {
        if let brewError = error as? HomebrewError {
            switch brewError {
            case .notFound:
                return LocalizationManager.shared.t("update.brew.notFound")
            case .invalidOutput:
                return LocalizationManager.shared.t("update.check.failed.title")
            case .commandFailed(let message):
                if message.isEmpty {
                    return LocalizationManager.shared.t("update.check.failed.title")
                }
                return String(format: LocalizationManager.shared.t("update.brew.commandFailed"), message)
            }
        }
        return error.localizedDescription
    }

    nonisolated private static func fetchHomebrewVersion(formula: String) throws -> String {
        let output = try runBrew(arguments: ["info", "--json=v2", formula])
        let data = Data(output.utf8)
        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: data)
        if let stable = response.formulae.first?.versions?.stable, !stable.isEmpty {
            return stable
        }
        if let caskVersion = response.casks.first?.version, !caskVersion.isEmpty {
            return caskVersion
        }
        throw HomebrewError.invalidOutput
    }

    nonisolated private static func runBrew(arguments: [String]) throws -> String {
        guard let brewURL = brewExecutableURL() else {
            throw HomebrewError.notFound
        }

        let process = Process()
        process.executableURL = brewURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw HomebrewError.commandFailed(error.localizedDescription)
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw HomebrewError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    nonisolated private static func brewExecutableURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/usr/bin/brew"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    nonisolated private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(from: lhs)
        let right = versionComponents(from: rhs)
        let maxCount = max(left.count, right.count)
        for index in 0..<maxCount {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    nonisolated private static func versionComponents(from version: String) -> [Int] {
        var components: [Int] = []
        var buffer = ""
        for char in version {
            if char.isNumber {
                buffer.append(char)
            } else if !buffer.isEmpty {
                components.append(Int(buffer) ?? 0)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            components.append(Int(buffer) ?? 0)
        }
        return components
    }
}

private enum HomebrewError: Error {
    case notFound
    case invalidOutput
    case commandFailed(String)
}

private struct BrewInfoResponse: Decodable {
    let formulae: [BrewFormula]
    let casks: [BrewCask]
}

private struct BrewFormula: Decodable {
    let versions: BrewVersions?
}

private struct BrewVersions: Decodable {
    let stable: String?
}

private struct BrewCask: Decodable {
    let version: String?
}

#if canImport(Sparkle)
extension UpdateManager: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        appcastURLString
    }
}
#endif
