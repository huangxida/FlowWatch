import SwiftUI
import AppKit

struct AboutView: View {
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(14)
                .shadow(radius: 2)

            Text(appName)
                .font(.title3.weight(.semibold))

            Text(AppVersion.displayString)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                openGitHub()
            } label: {
                Label(l10n.t("about.github"), systemImage: "link")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(minWidth: 320, minHeight: 240)
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "FlowWatch"
    }

    private func openGitHub() {
        guard let url = URL(string: "https://github.com/huangxida/FlowWatch") else { return }
        NSWorkspace.shared.open(url)
    }
}

#if DEBUG
#Preview {
    AboutView()
        .environmentObject(LocalizationManager.shared)
        .environment(\.locale, LocalizationManager.shared.locale)
}
#endif
