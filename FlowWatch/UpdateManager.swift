//
//  UpdateManager.swift
//  FlowWatch
//
//  Created by xida huang on 1/22/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()
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
    private let autoCheckEnabledKey = "update.autoCheckEnabled"
    private let autoCheckInterval: TimeInterval = 60 * 60 * 24
    private let homebrewFormula = "flowwatch"
    private let notificationCenter = UpdateNotificationCenter.shared
    private static let githubReleaseAPIURL = URL(string: "https://api.github.com/repos/huangxida/FlowWatch/releases/latest")
    private static let githubReleasePageURL = "https://github.com/huangxida/FlowWatch/releases/latest"
    private static let githubUserAgent = "FlowWatch"

    init(installMethod: InstallMethod = InstallMethodDetector.detect()) {
        self.installMethod = installMethod
        super.init()
    }

    var canCheckForUpdates: Bool {
        switch installMethod {
        case .homebrew:
            return status != .updating
        case .dmg:
            return status != .updating
        }
    }

    func checkForUpdates(userInitiated: Bool) {
        recordLastCheck()
        switch installMethod {
        case .homebrew:
            checkHomebrew(userInitiated: userInitiated)
        case .dmg:
            checkGitHubRelease(userInitiated: userInitiated)
        }
    }

    func checkForUpdatesIfNeeded() {
        guard shouldAutoCheck() else { return }
        checkForUpdates(userInitiated: false)
    }

    private func checkGitHubRelease(userInitiated _: Bool) {
        status = .checking
        let currentVersion = AppVersion.shortVersion
        Task.detached { [weak self] in
            do {
                let release = try await Self.fetchLatestRelease()
                let latestVersion = Self.normalizedVersion(release.tagName)
                guard !latestVersion.isEmpty else {
                    throw GitHubUpdateError.invalidRelease
                }
                let isNewer = Self.compareVersions(latestVersion, currentVersion) == .orderedDescending
                await MainActor.run {
                    guard let self else { return }
                    if isNewer {
                        self.status = .updateAvailable(version: latestVersion)
                        self.notifyGitHubUpdateAvailable(
                            version: latestVersion,
                            releaseURLString: release.htmlURL,
                            downloadURLString: release.dmgDownloadURL
                        )
                    } else {
                        self.status = .upToDate
                        self.notifyUpToDate()
                        self.status = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = .failed(message: self.message(for: error))
                    self.notifyCheckFailed(message: self.message(for: error))
                    self.status = .idle
                }
            }
        }
    }

    private func checkHomebrew(userInitiated _: Bool) {
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
                        self.notifyUpdateAvailable(
                            version: latestVersion,
                            messageKey: "update.available.message",
                        ) { [weak self] in
                            self?.performHomebrewUpgrade()
                        }
                    } else {
                        self.status = .upToDate
                        self.notifyUpToDate()
                        self.status = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = .failed(message: self.message(for: error))
                    self.notifyCheckFailed(message: self.message(for: error))
                    self.status = .idle
                }
            }
        }
    }

    private func notifyUpToDate() {
        notificationCenter.post(
            title: LocalizationManager.shared.t("update.check.upToDate.title"),
            body: LocalizationManager.shared.t("update.check.upToDate.message")
        )
    }

    private func notifyCheckFailed(message: String) {
        notificationCenter.post(
            title: LocalizationManager.shared.t("update.check.failed.title"),
            body: String(format: LocalizationManager.shared.t("update.check.failed.message"), message)
        )
    }

    private func notifyUpdateAvailable(version: String, messageKey: String, primaryAction: @escaping () -> Void) {
        notificationCenter.post(
            title: String(format: LocalizationManager.shared.t("update.available.title"), version),
            body: LocalizationManager.shared.t(messageKey),
            action: primaryAction
        )
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
                    self.notifyUpgradeSuccess()
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = .idle
                    self.notifyUpgradeFailed(message: self.message(for: error))
                }
            }
        }
    }

    private func notifyUpgradeSuccess() {
        notificationCenter.post(
            title: LocalizationManager.shared.t("update.upgrade.success.title"),
            body: LocalizationManager.shared.t("update.upgrade.success.message")
        )
    }

    private func notifyUpgradeFailed(message: String) {
        notificationCenter.post(
            title: LocalizationManager.shared.t("update.upgrade.failed.title"),
            body: String(format: LocalizationManager.shared.t("update.upgrade.failed.message"), message)
        )
    }

    private func notifyGitHubUpdateAvailable(version: String, releaseURLString: String?, downloadURLString: String?) {
        let messageKey = "update.available.message.dmg"
        notifyUpdateAvailable(version: version, messageKey: messageKey) { [weak self] in
            self?.openUpdateURL(releaseURLString: releaseURLString, downloadURLString: downloadURLString)
        }
    }

    private func openUpdateURL(releaseURLString: String?, downloadURLString _: String?) {
        let fallback = Self.githubReleasePageURL
        let urlString = releaseURLString ?? fallback
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func recordLastCheck() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
    }

    private func shouldAutoCheck() -> Bool {
        guard isAutoCheckEnabled() else { return false }
        let lastTimestamp = UserDefaults.standard.double(forKey: lastCheckKey)
        if lastTimestamp <= 0 {
            return true
        }
        let lastDate = Date(timeIntervalSince1970: lastTimestamp)
        return Date().timeIntervalSince(lastDate) >= autoCheckInterval
    }

    private func isAutoCheckEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: autoCheckEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: autoCheckEnabledKey)
    }

    nonisolated private static func fetchLatestRelease() async throws -> GitHubRelease {
        do {
            return try await fetchLatestReleaseFromAPI()
        } catch {
            return try await fetchLatestReleaseFromRedirect()
        }
    }

    nonisolated private static func fetchLatestReleaseFromAPI() async throws -> GitHubRelease {
        guard let url = githubReleaseAPIURL else {
            throw GitHubUpdateError.invalidRelease
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(githubUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubUpdateError.invalidRelease
        }
        if httpResponse.statusCode == 403,
           httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            throw GitHubUpdateError.rateLimited
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubUpdateError.invalidRelease
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    nonisolated private static func fetchLatestReleaseFromRedirect() async throws -> GitHubRelease {
        guard let url = URL(string: githubReleasePageURL) else {
            throw GitHubUpdateError.invalidRelease
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let finalURL = response.url else {
            throw GitHubUpdateError.invalidRelease
        }
        let tag = finalURL.lastPathComponent
        guard !tag.isEmpty else {
            throw GitHubUpdateError.invalidRelease
        }
        let htmlURL = "https://github.com/huangxida/FlowWatch/releases/tag/\(tag)"
        let downloadURL = "https://github.com/huangxida/FlowWatch/releases/download/\(tag)/FlowWatch.dmg"
        let asset = GitHubAsset(name: "FlowWatch.dmg", browserDownloadURL: downloadURL)
        return GitHubRelease(tagName: tag, htmlURL: htmlURL, assets: [asset])
    }

    nonisolated private static func normalizedVersion(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return LocalizationManager.shared.t("update.network.error")
            default:
                break
            }
        }
        if let githubError = error as? GitHubUpdateError {
            switch githubError {
            case .invalidRelease:
                return LocalizationManager.shared.t("update.github.invalidRelease")
            case .rateLimited:
                return LocalizationManager.shared.t("update.github.rateLimited")
            }
        }
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

private enum GitHubUpdateError: Error {
    case invalidRelease
    case rateLimited
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubAsset]

    init(tagName: String, htmlURL: String, assets: [GitHubAsset]) {
        self.tagName = tagName
        self.htmlURL = htmlURL
        self.assets = assets
    }

    var dmgDownloadURL: String? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }?.browserDownloadURL
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    init(name: String, browserDownloadURL: String) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
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
