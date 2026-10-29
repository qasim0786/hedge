import SwiftUI

struct ActivityView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RECORD")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.moss)
                Text("What Hedge has recorded")
                    .font(Theme.serif(40))
                    .foregroundStyle(Theme.ink)
                Text(ActivityLog.blurb)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
            }

            if model.activity.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing recorded yet.")
                        .font(Theme.serif(26))
                        .foregroundStyle(Theme.ink)
                    Text("Trims and memory quits show up here.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 12)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.activity) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.ink)
                                    Text(entry.detail)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.mute)
                                }
                                Spacer(minLength: 12)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(entry.bytes > 0 ? Format.bytes(entry.bytes) : "—")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(entry.ok ? Theme.moss : Theme.clay)
                                    Text(Format.when(entry.date))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.mute)
                                }
                            }
                            .padding(16)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Theme.line, lineWidth: 1)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
