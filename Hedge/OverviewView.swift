import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            if model.needsAccess {
                access
            } else if model.phase == .scanning && model.categories.isEmpty {
                scanning
            } else if model.categories.isEmpty && model.phase == .ready {
                empty
            } else {
                browser
            }
            Text(footer)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .topLeading) {
            RadialGradient(
                colors: [Theme.moss.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.moss)
                    number
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                }
                Spacer(minLength: 16)
                HStack(spacing: 8) {
                    Button(scanTitle) {
                        if model.needsAccess {
                            model.allowHomeFolder()
                        } else if model.phase == .scanning {
                            model.stopScan()
                        } else {
                            model.startScan()
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.phase == .cleaning)

                    Button(trimTitle) {
                        model.askToTrim()
                    }
                    .buttonStyle(MossButtonStyle())
                    .disabled(model.phase != .ready || model.selectedBytes == 0)
                }
                .padding(.top, 18)
            }

            if model.phase == .scanning {
                SweepLine()
            } else {
                meter
            }
        }
    }

    private var footer: String {
        var text = "Documents, photos, mail, and passwords are outside this scan."
        if FolderAccess.isSandboxed {
            text += " System temporary files stay sealed off from App Store apps."
        }
        return text
    }

    private var scanTitle: String {
        if model.needsAccess { return "Allow Folder" }
        if model.phase == .scanning { return "Stop" }
        return model.categories.isEmpty ? "Scan" : "Scan again"
    }

    private var eyebrow: String {
        if model.needsAccess { return "SANDBOX" }
        switch model.phase {
        case .scanning: return "MEASURING"
        case .cleaning: return "TRIMMING"
        case .ready: return "SELECTED"
        }
    }

    private var number: some View {
        let showDash = model.needsAccess || (model.phase == .scanning && model.categories.isEmpty)
        let parts = Format.parts(model.selectedBytes)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(showDash ? "—" : parts.value)
                .font(Theme.serif(78))
                .tracking(-1.6)
                .contentTransition(.numericText())
            if !showDash {
                Text(parts.unit)
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.mute)
            }
        }
        .foregroundStyle(Theme.ink)
        .animation(.snappy, value: parts.value)
    }

    private var subtitle: String {
        if model.needsAccess {
            return "Choose your home folder to measure caches."
        }
        switch model.phase {
        case .scanning:
            return model.progress
        case .cleaning:
            return model.progress
        case .ready:
            if let notice = model.notice, model.foundBytes == 0 {
                return notice
            }
            if model.foundBytes == 0 {
                return "Nothing obvious to trim."
            }
            if model.selectedBytes != model.foundBytes {
                return "\(Format.bytes(model.foundBytes)) found. Unchecked items stay."
            }
            if let notice = model.notice {
                return "\(notice). \(Format.bytes(model.foundBytes)) still reclaimable."
            }
            return "Across caches, logs, and developer tools."
        }
    }

    private var trimTitle: String {
        if model.phase == .cleaning { return "Trimming" }
        if model.selectedBytes == 0 { return "Trim" }
        return "Trim \(Format.bytes(model.selectedBytes))"
    }

    private var meter: some View {
        let total = max(model.health.diskTotal, 1)
        let free = max(model.health.diskFree, 0)
        let used = max(0, model.health.diskTotal - free)
        let reclaim = min(max(model.foundBytes, 0), used)
        let other = max(0, used - reclaim)
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let span = CGFloat(total)
                HStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.16)).frame(width: width * CGFloat(other) / span)
                    Rectangle().fill(Theme.moss).frame(width: width * CGFloat(reclaim) / span)
                    Rectangle().fill(Color.white.opacity(0.06)).frame(width: width * CGFloat(min(free, model.health.diskTotal)) / span)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            HStack(spacing: 16) {
                legend(Theme.mute, "In use")
                legend(Theme.moss, "Can trim")
                legend(Color.white.opacity(0.28), "Free")
                Spacer()
                if model.health.diskTotal > 0 {
                    Text("\(Format.bytes(model.health.diskFree)) free")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mute)
                }
            }
        }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hedge needs to see your home folder.")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("macOS keeps App Store apps in a sandbox. Choose the home folder once. Caches can be measured after that, and nothing is removed until you trim.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mute)
                .frame(maxWidth: 520, alignment: .leading)
            if let note = model.accessNote {
                Text(note)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.clay)
            }
            Button("Choose Home Folder") {
                model.allowHomeFolder()
            }
            .buttonStyle(MossButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 12)
    }

    private var scanning: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Walking caches, logs, and developer leftovers.")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("Nothing is deleted during a scan.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 12)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Already tidy.")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text(model.notice ?? "Hedge didn’t find caches worth trimming.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var browser: some View {
        HStack(alignment: .top, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(CleanGroup.allCases, id: \.self) { group in
                        let rows = model.categories.filter { $0.group == group }
                        if !rows.isEmpty {
                            Text(group.title.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.3)
                                .foregroundStyle(group == .permanent ? Theme.clay : Theme.mute)
                                .padding(.leading, 6)
                            VStack(spacing: 6) {
                                ForEach(rows) { category in
                                    CategoryRow(
                                        category: category,
                                        maxBytes: max(model.categories.map(\.bytes).max() ?? 1, 1),
                                        active: model.selectedCategory?.id == category.id,
                                        onToggle: { model.toggleCategory(category.id) },
                                        onSelect: { model.selectedCategoryID = category.id }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(width: 360)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var detail: some View {
        let category = model.selectedCategory
        return VStack(alignment: .leading, spacing: 14) {
            if let category {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text(category.blurb)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Text(Format.bytes(category.selectedBytes))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.moss)
                }

                if category.items.count > 6 {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.mute)
                        TextField("Filter", text: $query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                ScrollView {
                    let items = filtered(category.items)
                    if items.isEmpty {
                        Text("Nothing matches.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mute)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(items) { item in
                                ItemRow(item: item) {
                                    model.toggleItem(category: category.id, item: item.id)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Pick a group.")
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        }
        .onChange(of: model.selectedCategoryID) { _, _ in
            query = ""
        }
    }

    private func filtered(_ items: [CleanItem]) -> [CleanItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(needle) || $0.detail.localizedCaseInsensitiveContains(needle)
        }
    }
}

private struct CategoryRow: View {
    let category: CleanCategory
    let maxBytes: Int64
    let active: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HedgeCheck(state: category.allSelected ? .on : (category.someSelected ? .mixed : .off))
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(category.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(sizeLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(category.someSelected ? Theme.moss : Theme.mute)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(category.group == .permanent ? Theme.clay.opacity(0.85) : Theme.moss.opacity(0.9))
                                .frame(width: max(4, geo.size.width * CGFloat(category.bytes) / CGFloat(maxBytes)))
                        }
                    }
                    .frame(height: 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? Color.white.opacity(0.05) : (hover ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if active {
                Capsule()
                    .fill(category.group == .permanent ? Theme.clay : Theme.moss)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 4)
            }
        }
        .onHover { hover = $0 }
    }

    private var sizeLabel: String {
        if category.someSelected && !category.allSelected {
            return "\(Format.bytes(category.selectedBytes)) of \(Format.bytes(category.bytes))"
        }
        return Format.bytes(category.bytes)
    }
}

private struct ItemRow: View {
    let item: CleanItem
    let onToggle: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    HedgeCheck(state: item.selected ? .on : .off)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if item.safety == .trashChild {
                                Text("PERMANENT")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(Theme.clay)
                            }
                        }
                        Text(item.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                    Text(Format.bytes(item.bytes))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.selected ? Theme.ink : Theme.mute)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let path = item.paths.first?.path {
                Button {
                    Finder.reveal(path)
                } label: {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.mute)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
                .opacity(hover ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(hover ? Color.white.opacity(0.03) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hover = $0 }
    }
}
