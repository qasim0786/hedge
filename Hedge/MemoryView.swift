import SwiftUI

struct MemoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MEMORY")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.moss)
                    Text("What’s holding on")
                        .font(Theme.serif(40))
                        .foregroundStyle(Theme.ink)
                    Text("Quit apps you pick. macOS already reclaims caches on its own.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(pressureWord)
                            .font(Theme.serif(36))
                            .foregroundStyle(pressureColor)
                        Spacer()
                        Text(usedText)
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(pressureCaption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mute)
                    bar
                    HStack(spacing: 16) {
                        legend(Theme.moss, "App")
                        legend(Color.white.opacity(0.45), "Wired")
                        legend(Theme.amber, "Compressed")
                        legend(Color.white.opacity(0.2), "Free")
                        Spacer()
                    }
                    Text(cachedLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mute)
                    if let swap = model.health.swapUsed {
                        Text(swap == 0 ? "No swap in use." : "Swap in use: \(Format.bytes(Int64(swap))). Quitting a few apps will help.")
                            .font(.system(size: 13))
                            .foregroundStyle(swap == 0 ? Theme.mute : Theme.amber)
                    }
                }
                .padding(18)
                .hedgePanel()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OPEN APPS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        if !model.apps.isEmpty {
                            Button(allSelected ? "Clear" : "Select all") {
                                if allSelected {
                                    model.clearQuit()
                                } else {
                                    model.selectAllQuit()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.moss)
                        }
                    }

                    if model.apps.isEmpty {
                        Text("No other apps are open.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.mute)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 2) {
                            ForEach(model.apps) { app in
                                AppQuitRow(
                                    app: app,
                                    on: model.quitSelection.contains(app.id),
                                    onToggle: { model.toggleQuit(app.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .hedgePanel()
                    }

                    if let note = model.memoryNote {
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mute)
                    }

                    HStack(spacing: 8) {
                        Button(quitTitle) { model.askToQuit() }
                            .buttonStyle(MossButtonStyle())
                            .disabled(model.quitting || model.quitPlans.isEmpty)
                        Button("Activity Monitor") { model.openActivityMonitor() }
                            .buttonStyle(GhostButtonStyle())
                    }
                }

                Text("Quitting asks an app to close. It can still show a save dialog. Cached memory is left alone, because macOS gives it back when something needs it.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [Theme.moss.opacity(0.06), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    private var allSelected: Bool {
        !model.apps.isEmpty && model.apps.allSatisfy { model.quitSelection.contains($0.id) }
    }

    private var usedText: String {
        guard model.health.memoryTotal > 0 else { return "Measuring" }
        return Format.bytes(Int64(model.health.memoryUsed))
    }

    private var pressureWord: String {
        switch model.memoryPressure {
        case .critical: "Strained"
        case .warning: "Tight"
        case .normal: "Steady"
        case .unknown: estimatedWord
        }
    }

    private var estimatedWord: String {
        guard model.health.memoryTotal > 0 else { return "Reading" }
        let fraction = Double(model.health.memoryUsed) / Double(model.health.memoryTotal)
        if fraction < 0.70 { return "Steady" }
        if fraction < 0.85 { return "Busy" }
        if fraction < 0.93 { return "Tight" }
        return "Strained"
    }

    private var pressureCaption: String {
        switch model.memoryPressure {
        case .critical: "macOS reports critical memory pressure."
        case .warning: "macOS reports memory pressure."
        case .normal: "macOS reports steady pressure."
        case .unknown: "Estimated from memory in use. macOS will report pressure if it changes."
        }
    }

    private var pressureColor: Color {
        switch pressureWord {
        case "Strained": Theme.clay
        case "Tight", "Busy": Theme.amber
        default: Theme.moss
        }
    }

    private var cachedLine: String {
        guard model.health.memoryTotal > 0 else { return "Measuring caches." }
        return "Cached \(Format.bytes(Int64(model.health.memoryCached))), ready for reuse. Free \(Format.bytes(Int64(model.health.memoryFree)))."
    }

    private var bar: some View {
        let total = max(model.health.memoryTotal, 1)
        var app = Double(model.health.memoryApp)
        var wired = Double(model.health.memoryWired)
        var compressed = Double(model.health.memoryCompressed)
        let raw = app + wired + compressed
        if raw > Double(total), raw > 0 {
            let scale = Double(total) / raw
            app *= scale
            wired *= scale
            compressed *= scale
        }
        let free = max(0, Double(total) - app - wired - compressed)
        return GeometryReader { geo in
            let width = geo.size.width
            let span = Double(total)
            HStack(spacing: 0) {
                Rectangle().fill(Theme.moss).frame(width: width * app / span)
                Rectangle().fill(Color.white.opacity(0.45)).frame(width: width * wired / span)
                Rectangle().fill(Theme.amber).frame(width: width * compressed / span)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: width * free / span)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var quitTitle: String {
        let count = model.quitPlans.count
        if model.quitting { return "Asking" }
        if count == 0 { return "Quit selected" }
        if count == 1 { return "Quit 1 app" }
        return "Quit \(count) apps"
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
        }
    }
}

private struct AppQuitRow: View {
    let app: QuitApp
    let on: Bool
    let onToggle: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                HedgeCheck(state: on ? .on : .off)
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(app.memory > 0 ? Format.bytes(Int64(app.memory)) : "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(on ? Theme.ink : Theme.mute)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hover ? Color.white.opacity(0.03) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hover = $0 }
    }
}

struct QuitOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { model.showQuitConfirm = false }

            VStack(alignment: .leading, spacing: 18) {
                Text("Quit these apps?")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)

                if model.quitBytes > 0 {
                    Text("About \(Format.bytes(Int64(model.quitBytes)))")
                        .font(Theme.serif(22))
                        .foregroundStyle(Theme.moss)
                }

                Text(bodyCopy)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.quitPlans.prefix(6))) { app in
                        Text(app.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink.opacity(0.9))
                            .lineLimit(1)
                    }
                    if model.quitPlans.count > 6 {
                        Text("and \(model.quitPlans.count - 6) more")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mute)
                    }
                }

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel") { model.showQuitConfirm = false }
                        .buttonStyle(GhostButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button(confirmTitle) { model.confirmQuit() }
                        .buttonStyle(MossButtonStyle())
                        .keyboardShortcut(.defaultAction)
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

    private var confirmTitle: String {
        let count = model.quitPlans.count
        return count == 1 ? "Quit 1 app" : "Quit \(count) apps"
    }

    private var bodyCopy: String {
        let count = model.quitPlans.count
        let noun = count == 1 ? "app" : "apps"
        return "\(count) \(noun) will be asked to quit. They can show a save dialog. Hedge does not force them closed. macOS may ask permission the first time."
    }
}
