import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            HStack(spacing: 0) {
                Rail()
                    .frame(width: 248)
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 1)
                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if model.showConfirm {
                ConfirmOverlay()
            } else if model.showQuitConfirm {
                QuitOverlay()
            } else if model.showDonate {
                DonateOverlay()
            }
        }
        .tint(Theme.moss)
        .onAppear(perform: styleWindow)
    }

    private func styleWindow() {
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows where window.canBecomeMain {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(srgbRed: 0.059, green: 0.071, blue: 0.059, alpha: 1)
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .overview:
            OverviewView()
        case .health:
            HealthView()
        case .memory:
            MemoryView()
        case .temperature:
            TemperatureView()
        case .security:
            SecurityView()
        case .activity:
            ActivityView()
        }
    }
}

struct Rail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HedgeMark(height: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text("hedge")
                        .font(Theme.serif(34))
                        .foregroundStyle(Theme.ink)
                    Text("Trim the overgrowth.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mute)
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 22)

            VStack(spacing: 4) {
                ForEach(Page.allCases) { page in
                    Button {
                        model.page = page
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: page.symbol)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 18)
                            Text(page.title)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 14, weight: model.page == page ? .semibold : .regular))
                        .foregroundStyle(model.page == page ? Theme.ink : Theme.mute)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            model.page == page ? Color.white.opacity(0.05) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.page == page ? .isSelected : [])
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 14)

            Spacer()

            Button {
                model.showDonate = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 18)
                    Text("Donate")
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mute)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .help("Support the developer")

            DiskRing()
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
        }
        .frame(maxHeight: .infinity)
        .background(Theme.rail)
    }
}

struct DiskRing: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let total = model.health.diskTotal
        let free = model.health.diskFree
        let fraction = total > 0 ? Double(free) / Double(total) : 0
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(Theme.moss, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(total > 0 ? "\(Int((fraction * 100).rounded()))" : "–")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text("Free")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mute)
                Text(total > 0 ? Format.bytes(free) : "Measuring")
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.ink)
                if total > 0 {
                    Text("of \(Format.bytes(total))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mute)
                }
            }
        }
    }
}

struct ConfirmOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { model.showConfirm = false }

            VStack(alignment: .leading, spacing: 18) {
                Text(model.permanentPlaces > 0 && model.permanentPlaces == model.selectedPlaces ? "Empty Trash?" : "Trim this?")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)

                Text(Format.bytes(model.selectedBytes))
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.moss)

                Text(bodyCopy)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)

                if model.permanentPlaces > 0 && model.permanentPlaces != model.selectedPlaces {
                    Text("Includes \(Format.bytes(model.permanentBytes)) from Trash, which is deleted for good.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.clay)
                        .fixedSize(horizontal: false, vertical: true)
                }

                nameList

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel") { model.showConfirm = false }
                        .buttonStyle(GhostButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    if model.permanentPlaces > 0 && model.permanentPlaces == model.selectedPlaces {
                        Button("Empty Trash") { model.confirmTrim() }
                            .buttonStyle(ClayButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Trim \(Format.bytes(model.selectedBytes))") { model.confirmTrim() }
                            .buttonStyle(MossButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(28)
            .frame(width: 480)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
    }

    private var bodyCopy: String {
        if model.permanentPlaces > 0 && model.permanentPlaces == model.selectedPlaces {
            return "\(model.permanentPlaces) items will be deleted from Trash. This cannot be undone."
        }
        let recoverable = model.selectedPlaces - model.permanentPlaces
        return "\(recoverable) items move to Trash. You can put them back from there. Documents, photos, mail, and passwords are not in this trim."
    }

    private var nameList: some View {
        let names = model.confirmPlans.map(\.name)
        let shown = Array(names.prefix(6))
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink.opacity(0.9))
                    .lineLimit(1)
            }
            if names.count > shown.count {
                Text("and \(names.count - shown.count) more")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
            }
        }
    }
}

enum Finder {
    static func reveal(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
