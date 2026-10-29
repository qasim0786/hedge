import AppKit
import SwiftUI

struct SecurityView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SECURITY")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.moss)
                        Text("What’s fastened")
                            .font(Theme.serif(40))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer(minLength: 16)
                    Button(model.securityBusy ? "Checking" : "Check again") {
                        model.startSecurity()
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.securityBusy)
                    .padding(.top, 28)
                }

                if model.checks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reading FileVault, the firewall, Gatekeeper, and the rest.")
                            .font(Theme.serif(26))
                            .foregroundStyle(Theme.ink)
                        Text("Nothing is changed.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.mute)
                        SweepLine()
                    }
                    .padding(.top, 8)
                } else {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)

                    VStack(spacing: 8) {
                        ForEach(model.checks) { check in
                            row(check)
                        }
                    }
                }

                Text("Hedge only reads these switches. It doesn’t change them, and it doesn’t scan your files for malware.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .background(alignment: .topLeading) {
            RadialGradient(
                colors: [Theme.moss.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .onAppear {
            if model.securityChecked == nil {
                model.startSecurity()
            }
        }
    }

    private var subtitle: String {
        if let date = model.securityChecked {
            return "\(Format.system) · checked \(Format.when(date))"
        }
        return Format.system
    }

    private var summary: String {
        if model.securityBusy { return "Checking again. Nothing is changed." }
        let attention = model.checks.filter { $0.state == .attention }.count
        let unknown = model.checks.filter { $0.state == .unknown }.count
        if attention == 0, unknown == 0 { return "Everything Hedge could read looks fastened." }
        var parts: [String] = []
        if attention > 0 { parts.append("\(attention) to review") }
        if unknown > 0 { parts.append("\(unknown) unread") }
        return parts.joined(separator: " · ")
    }

    private func row(_ check: SecurityCheck) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(color(check.state))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(check.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            action(for: check)
        }
        .padding(16)
        .hedgePanel(corner: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.title), \(check.state.label). \(check.detail)")
    }

    @ViewBuilder
    private func action(for check: SecurityCheck) -> some View {
        if check.id == "access", check.state == .attention {
            Button("Allow") { model.allowHomeFolder() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.moss)
        } else if let target = check.settingsURL, check.state != .pass {
            Button("Settings") { open(target) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.moss)
        }
    }

    private func color(_ state: SecurityState) -> Color {
        switch state {
        case .pass: Theme.moss
        case .attention: Theme.clay
        case .unknown: Theme.mute
        }
    }

    private func open(_ target: String) {
        guard let url = URL(string: target) else { return }
        NSWorkspace.shared.open(url)
    }
}
