import SwiftUI

enum Theme {
    static let bg = Color(red: 0.059, green: 0.071, blue: 0.059)
    static let rail = Color(red: 0.043, green: 0.051, blue: 0.043)
    static let card = Color(red: 0.102, green: 0.118, blue: 0.102)
    static let ink = Color(red: 0.957, green: 0.941, blue: 0.898)
    static let mute = Color(red: 0.576, green: 0.612, blue: 0.549)
    static let moss = Color(red: 0.839, green: 1.0, blue: 0.290)
    static let soil = Color(red: 0.086, green: 0.102, blue: 0.031)
    static let clay = Color(red: 1.0, green: 0.416, blue: 0.302)
    static let amber = Color(red: 0.961, green: 0.761, blue: 0.361)
    static let line = Color.white.opacity(0.08)

    static func serif(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct HedgeMark: View {
    var height: CGFloat = 22

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.14) {
            bar(0.62)
            bar(1.0)
            bar(0.74)
            bar(0.48)
        }
        .frame(height: height)
        .foregroundStyle(Theme.moss)
    }

    private func bar(_ scale: CGFloat) -> some View {
        Capsule()
            .frame(width: height * 0.28, height: height * scale)
    }
}

struct HedgeCheck: View {
    var state: CheckState

    enum CheckState {
        case off, mixed, on
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(state == .on ? Theme.moss : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(state == .off ? Color.white.opacity(0.22) : Theme.moss, lineWidth: 1.4)
            }
            .overlay {
                switch state {
                case .on:
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.soil)
                case .mixed:
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Theme.moss)
                        .frame(width: 8, height: 2)
                case .off:
                    EmptyView()
                }
            }
            .frame(width: 16, height: 16)
    }
}

struct MossButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.soil)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.moss, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.32)
    }
}

struct ClayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.18, green: 0.05, blue: 0.03))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.clay, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Theme.line, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SweepLine: View {
    @State private var slide = false

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Theme.moss)
                .frame(width: max(48, geo.size.width * 0.22), height: 2)
                .offset(x: slide ? geo.size.width * 0.78 : 0)
        }
        .frame(height: 2)
        .background(Color.white.opacity(0.06), in: Capsule())
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                slide = true
            }
        }
    }
}

extension View {
    func hedgePanel(corner: CGFloat = 18) -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}
