import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("statusBarDisplayMode") private var statusBarDisplayModeRaw: String = FlowWatchApp.StatusBarDisplayMode.speed.rawValue
    @AppStorage("maxColorRateMbps") private var maxColorRateMbps: Double = 100
    @AppStorage("colorRatePercent") private var colorRatePercent: Double = 100
    @AppStorage("update.autoCheckEnabled") private var autoCheckEnabled: Bool = true
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var isShowingResetAlert = false
    @State private var resetAlertMode: ResetAlertMode?
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus: SMAppService.Status?
    @State private var launchAtLoginErrorMessage: String?
    @FocusState private var focusedField: FocusField?
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            
            GroupBox {
                HStack {
                    Text(l10n.t("settings.language"))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { l10n.language },
                        set: { l10n.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(languageLabel(language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(l10n.t("settings.displayContent.label"))
                        Spacer()
                        Picker("", selection: $statusBarDisplayModeRaw) {
                            ForEach(FlowWatchApp.StatusBarDisplayMode.allCases, id: \.rawValue) { mode in
                                Text(l10n.t(mode.titleKey)).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                sectionLabel(l10n.t("settings.section.statusBar"), systemImage: "menubar.rectangle")
            }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(l10n.t("settings.maxColorRate.limitTitle"))
                            Spacer()
                            HStack(spacing: 6) {
                                TextField(
                                    "",
                                    value: maxColorRateInputBinding,
                                    format: .number.precision(.fractionLength(0))
                                )
                                .frame(width: 72)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .maxColorRate)
                                Text("Mbps")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Text(l10n.t("settings.maxColorRate.intensityTitle"))
                            Spacer()
                            Text("\(Int(colorRatePercent.rounded()))%")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: colorRatePercentBinding, in: 0...100, step: 1)
                        Text(l10n.t("settings.maxColorRate.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                sectionLabel(l10n.t("settings.section.coloring"), systemImage: "paintpalette")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if #available(macOS 13.0, *) {
                        Toggle(l10n.t("settings.launchAtLogin.toggle"), isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { newValue in
                                toggleLaunchAtLogin(to: newValue)
                            }
                        ))

                        if let status = launchAtLoginStatus,
                           let hint = launchAtLoginHintText(for: status) {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Toggle(l10n.t("settings.launchAtLogin.toggle"), isOn: .constant(false))
                            .disabled(true)
                        Text(l10n.t("settings.requires.macos13"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                sectionLabel(l10n.t("settings.section.launch"), systemImage: "power")
            }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(l10n.t("settings.update.autoCheck"), isOn: Binding(
                            get: { autoCheckEnabled },
                            set: { newValue in
                                autoCheckEnabled = newValue
                                if newValue {
                                    NotificationCenter.default.post(name: .flowWatchCheckForUpdates, object: nil)
                                }
                            }
                        ))
                        if updateManager.status == .checking {
                            Text(l10n.t("menu.checkingUpdate"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(l10n.t("settings.update.hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                sectionLabel(l10n.t("settings.section.updates"), systemImage: "arrow.triangle.2.circlepath")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Button(l10n.t("settings.data.resetToday"), role: .destructive) {
                        resetAlertMode = .today
                        isShowingResetAlert = true
                    }
                    Button(l10n.t("settings.data.clearAllHistory"), role: .destructive) {
                        resetAlertMode = .allHistory
                        isShowingResetAlert = true
                    }
                    Text(l10n.t("settings.data.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                sectionLabel(l10n.t("settings.section.data"), systemImage: "internaldrive")
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 680, alignment: .topLeading)
        .onAppear {
            refreshLaunchAtLoginState()
            DispatchQueue.main.async {
                focusedField = nil
            }
        }
        .alert(l10n.t("alert.reset.title"), isPresented: $isShowingResetAlert) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(resetAlertMode == .allHistory ? l10n.t("common.clear") : l10n.t("common.reset"), role: .destructive) {
                switch resetAlertMode {
                case .today:
                    NotificationCenter.default.post(name: .flowWatchResetToday, object: nil)
                case .allHistory:
                    NotificationCenter.default.post(name: .flowWatchResetAllHistory, object: nil)
                case .none:
                    break
                }
            }
        } message: {
            switch resetAlertMode {
            case .today:
                Text(l10n.t("alert.reset.today"))
            case .allHistory:
                Text(l10n.t("alert.reset.all"))
            case .none:
                Text("")
            }
        }
        .alert(l10n.t("alert.launchAtLogin.errorTitle"), isPresented: Binding(
            get: { launchAtLoginErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    launchAtLoginErrorMessage = nil
                }
            }
        )) {
            Button(l10n.t("common.ok")) {}
        } message: {
            Text(launchAtLoginErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(l10n.t("settings.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private enum ResetAlertMode {
        case today
        case allHistory
    }

    private enum FocusField {
        case maxColorRate
    }

    private var maxColorRateInputBinding: Binding<Double> {
        Binding(
            get: { maxColorRateMbps },
            set: { newValue in
                maxColorRateMbps = max(0, newValue)
            }
        )
    }

    private var colorRatePercentBinding: Binding<Double> {
        Binding(
            get: { min(max(colorRatePercent, 0), 100) },
            set: { newValue in
                colorRatePercent = max(0, min(newValue, 100))
            }
        )
    }

    private func refreshLaunchAtLoginState() {
        guard #available(macOS 13.0, *) else { return }
        launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled
        launchAtLoginStatus = LaunchAtLoginManager.shared.status
    }

    @available(macOS 13.0, *)
    private func toggleLaunchAtLogin(to enabled: Bool) {
        do {
            try LaunchAtLoginManager.shared.setEnabled(enabled)
        } catch {
            refreshLaunchAtLoginState()
            if LaunchAtLoginManager.shared.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                launchAtLoginErrorMessage = l10n.t("alert.launchAtLogin.needsApproval")
            } else {
                launchAtLoginErrorMessage = String(format: l10n.t("alert.launchAtLogin.failed"), error.localizedDescription)
            }
        }

        refreshLaunchAtLoginState()
    }

    @available(macOS 13.0, *)
    private func launchAtLoginHintText(for status: SMAppService.Status) -> String? {
        switch status {
        case .enabled:
            return l10n.t("settings.launchAtLogin.hint.enabled")
        case .notRegistered:
            return l10n.t("settings.launchAtLogin.hint.notRegistered")
        case .requiresApproval:
            return l10n.t("settings.launchAtLogin.hint.requiresApproval")
        case .notFound:
            return l10n.t("settings.launchAtLogin.hint.notFound")
        @unknown default:
            return nil
        }
    }
    
    private func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            return l10n.t("settings.language.system")
        case .zhHans:
            return l10n.t("settings.language.zhHans")
        case .en:
            return l10n.t("settings.language.en")
        }
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(LocalizationManager.shared)
        .environment(\.locale, LocalizationManager.shared.locale)
}
#endif
