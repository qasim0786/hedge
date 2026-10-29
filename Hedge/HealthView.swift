import SwiftUI

struct HealthView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("THIS MAC")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.moss)
                    Text("How it’s breathing")
                        .font(Theme.serif(40))
                        .foregroundStyle(Theme.ink)
                    uptimeLine
                }

                HStack(spacing: 12) {
                    MeterCard(
                        title: "Processor",
                        value: cpuValue,
                        caption: String(format: "Load %.2f  %.2f  %.2f", model.health.load1, model.health.load5, model.health.load15),
                        fraction: model.health.cpu ?? 0
                    )
                    MeterCard(
                        title: "Memory",
                        value: model.health.memoryTotal > 0 ? Format.bytes(Int64(model.health.memoryUsed)) : "—",
                        caption: model.health.memoryTotal > 0 ? "of \(Format.bytes(Int64(model.health.memoryTotal)))" : "Measuring",
                        fraction: model.health.memoryTotal > 0 ? Double(model.health.memoryUsed) / Double(model.health.memoryTotal) : 0
                    )
                    MeterCard(
                        title: "Disk",
                        value: model.health.diskTotal > 0 ? Format.bytes(model.health.diskFree) : "—",
                        caption: "free",
                        fraction: model.health.diskTotal > 0 ? Double(model.health.diskFree) / Double(model.health.diskTotal) : 0
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("BUSY RIGHT NOW")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.mute)
                    VStack(spacing: 0) {
                        let top = model.health.processes.map(\.memory).max() ?? 1
                        ForEach(model.health.processes) { process in
                            HStack(spacing: 12) {
                                Text(process.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(Format.bytes(Int64(process.memory)))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.mute)
                                    .frame(width: 72, alignment: .trailing)
                            }
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Theme.moss.opacity(0.7))
                                        .frame(width: max(4, geo.size.width * CGFloat(process.memory) / CGFloat(top)), height: 2)
                                }
                                .frame(height: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.line, lineWidth: 1)
                    }
                }
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

    private var uptimeLine: some View {
        let uptime = Format.uptime(model.health.uptime)
        return HStack(spacing: 0) {
            if let thermal = model.health.thermal {
                Text(thermal.title)
                    .foregroundStyle(heatColor(thermal))
                Text(" · \(uptime)")
                    .foregroundStyle(Theme.mute)
            } else {
                Text(uptime)
                    .foregroundStyle(Theme.mute)
            }
        }
        .font(.system(size: 14))
    }

    private func heatColor(_ level: ThermalLevel) -> Color {
        switch level {
        case .nominal: Theme.moss
        case .fair: Theme.amber
        case .serious, .critical: Theme.clay
        }
    }

    private var cpuValue: String {
        guard let cpu = model.health.cpu else { return "—" }
        return "\(Int((cpu * 100).rounded()))%"
    }
}

private struct MeterCard: View {
    let title: String
    let value: String
    let caption: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.mute)
            Text(value)
                .font(Theme.serif(32))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(Theme.moss)
                        .frame(width: max(0, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        }
    }
}
