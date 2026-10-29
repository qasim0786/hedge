import SwiftUI

struct TemperatureView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TEMPERATURE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.moss)
                    Text("How warm it is")
                        .font(Theme.serif(40))
                        .foregroundStyle(Theme.ink)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.health.thermal?.title ?? "Reading")
                            .font(Theme.serif(64))
                            .foregroundStyle(heatColor)
                        Text(model.health.thermal?.detail ?? "Waiting for the thermal state macOS reports.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 16)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("PROCESSOR")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.mute)
                        Text(cpuValue)
                            .font(Theme.serif(40))
                            .foregroundStyle(Theme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("PROCESSOR")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.mute)
                    TraceChart(values: model.pulse.map(\.cpu))
                        .frame(height: 88)
                        .accessibilityLabel("Processor activity")
                    Text(model.pulse.count < 2 ? "The trace fills in over the next minute." : loadCaption)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mute)
                }
                .padding(18)
                .hedgePanel()

                VStack(alignment: .leading, spacing: 12) {
                    Text("RECENT THERMAL STATE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.mute)
                    if model.pulse.isEmpty {
                        Text("Samples show up as Hedge watches.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mute)
                    } else {
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(model.pulse.suffix(60))) { sample in
                                Capsule()
                                    .fill(color(sample.thermal))
                                    .frame(width: 4, height: 18)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 18)
                        .accessibilityLabel("Recent thermal state")
                    }
                }
                .padding(18)
                .hedgePanel()

                Text("App Store apps don’t receive raw sensor readings. This is the thermal state macOS uses when it decides to slow the machine down, sampled every couple of seconds, and it stays on this Mac.")
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
                colors: [heatColor.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
    }

    private var cpuValue: String {
        guard let cpu = model.health.cpu else { return "—" }
        return "\(Int((cpu * 100).rounded()))%"
    }

    private var loadCaption: String {
        String(format: "Load %.2f  %.2f  %.2f", model.health.load1, model.health.load5, model.health.load15)
    }

    private var heatColor: Color {
        guard let thermal = model.health.thermal else { return Theme.mute }
        return color(thermal)
    }

    private func color(_ level: ThermalLevel) -> Color {
        switch level {
        case .nominal: Theme.moss
        case .fair: Theme.amber
        case .serious, .critical: Theme.clay
        }
    }
}

private struct TraceChart: View {
    var values: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                if values.count > 1 {
                    Path { path in
                        let step = geo.size.width / CGFloat(values.count - 1)
                        for (index, value) in values.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geo.size.height * (1 - CGFloat(min(max(value, 0), 1)))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Theme.moss, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
