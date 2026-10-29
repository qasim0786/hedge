import Darwin
import Foundation

/// Hedge deletes only through `Cleaner.remove`, and that function asks `DeletionGuard` first.
enum DeletionGuard {
    static func approve(_ path: String, safety: Safety, home: String, downloads: String, temp: String) -> Bool {
        if path.isEmpty || path == "/" || path.contains("\0") { return false }
        if path.split(separator: "/").contains("..") { return false }

        let resolved = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        if resolved.isEmpty || resolved == "/" || resolved == home { return false }
        if banned(resolved, home: home) { return false }
        if resolved.hasPrefix("/System")
            || resolved.hasPrefix("/usr/")
            || resolved.hasPrefix("/bin")
            || resolved.hasPrefix("/sbin")
            || resolved.hasPrefix("/Applications")
            || resolved.hasPrefix("/Library/")
            || resolved.hasPrefix("/private/var/db")
            || resolved.hasPrefix("/private/var/root")
        {
            return false
        }

        switch safety {
        case .cacheChild:
            return directChild(resolved, of: home + "/Library/Caches") && !sensitive(resolved)
        case .logChild:
            let name = URL(fileURLWithPath: resolved).lastPathComponent
            return directChild(resolved, of: home + "/Library/Logs") && name != "Hedge" && !sensitive(resolved)
        case .trashChild:
            return directChild(resolved, of: home + "/.Trash")
        case .downloadsInstaller:
            return installer(resolved, downloads: downloads)
        case .derivedDataChild:
            return directChild(resolved, of: home + "/Library/Developer/Xcode/DerivedData")
        case .deviceSupportChild:
            let roots = [
                home + "/Library/Developer/Xcode/iOS DeviceSupport",
                home + "/Library/Developer/Xcode/watchOS DeviceSupport",
                home + "/Library/Developer/Xcode/tvOS DeviceSupport",
            ]
            return roots.contains { directChild(resolved, of: $0) }
        case .archiveChild:
            return directChild(resolved, of: home + "/Library/Developer/Xcode/Archives")
        case .tempChild:
            guard !temp.isEmpty else { return false }
            return directChild(resolved, of: temp)
                && (resolved.hasPrefix("/private/var/folders/") || resolved.hasPrefix("/var/folders/") || resolved.hasPrefix("/tmp/") || resolved.hasPrefix("/private/tmp/"))
        case .pinned(let pin):
            return resolved == pin.path(home: home)
        case .browserProfileCache:
            return Browser.isProfileCache(resolved, home: home)
        }
    }

    private static func banned(_ path: String, home: String) -> Bool {
        let exact: Set<String> = [
            home,
            home + "/Library",
            home + "/Library/Caches",
            home + "/Library/Logs",
            home + "/Library/Application Support",
            home + "/Library/Preferences",
            home + "/Library/Keychains",
            home + "/Library/Mail",
            home + "/Library/Messages",
            home + "/Library/Developer",
            home + "/Library/Developer/Xcode",
            home + "/Documents",
            home + "/Desktop",
            home + "/Pictures",
            home + "/Movies",
            home + "/Music",
            home + "/Downloads",
            home + "/.Trash",
            home + "/.npm",
            home + "/.cargo",
            home + "/.gradle",
            home + "/.ssh",
        ]
        return exact.contains(path)
    }

    private static func directChild(_ path: String, of root: String) -> Bool {
        guard path.hasPrefix(root + "/") else { return false }
        let rest = path.dropFirst(root.count + 1)
        return !rest.isEmpty && !rest.contains("/")
    }

    private static func sensitive(_ path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        let needles = ["password", "keychain", "cookie", "credential", "wallet", "secret", "token", "account", "session"]
        return needles.contains { name.contains($0) }
    }

    private static func installer(_ path: String, downloads: String) -> Bool {
        guard !downloads.isEmpty else { return false }
        let url = URL(fileURLWithPath: path)
        guard url.deletingLastPathComponent().path == downloads else { return false }
        let allowed = ["dmg", "pkg", "iso", "xip"]
        return allowed.contains(url.pathExtension.lowercased())
    }
}

enum Browser {
    static let cacheFolderNames: Set<String> = [
        "com.apple.Safari",
        "Google",
        "com.google.Chrome",
        "com.google.Chrome.helper",
        "BraveSoftware",
        "com.brave.Browser",
        "Microsoft Edge",
        "com.microsoft.Edge",
        "Firefox",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",
        "Arc",
        "com.kagi.kagimacOS",
    ]

    static let supportRoots = [
        "Library/Application Support/Google/Chrome",
        "Library/Application Support/Google/Chrome Canary",
        "Library/Application Support/BraveSoftware/Brave-Browser",
        "Library/Application Support/Microsoft Edge",
        "Library/Application Support/com.operasoftware.Opera",
        "Library/Application Support/Vivaldi",
        "Library/Application Support/Chromium",
        "Library/Application Support/Arc",
    ]

    static func isProfile(_ name: String) -> Bool {
        if name == "Default" || name == "Guest Profile" || name == "System Profile" { return true }
        guard name.hasPrefix("Profile ") else { return false }
        let suffix = name.dropFirst("Profile ".count)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }

    static func isProfileCache(_ path: String, home: String) -> Bool {
        for root in supportRoots {
            let prefix = home + "/" + root + "/"
            guard path.hasPrefix(prefix) else { continue }
            let parts = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
            if parts.count == 2 {
                return isProfile(parts[0]) && (parts[1] == "Cache" || parts[1] == "Code Cache" || parts[1] == "GPUCache")
            }
            if parts.count == 3 {
                return isProfile(parts[0]) && parts[1] == "Service Worker" && (parts[2] == "CacheStorage" || parts[2] == "ScriptCache")
            }
            return false
        }
        return false
    }
}

enum Locations {
    /// Real account home. `NSHomeDirectory()` points at the sandbox container.
    static let home: String = {
        if let dir = getpwuid(getuid())?.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty {
                return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
    }()

    static var downloads: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.resolvingSymlinksInPath().path ?? ""
    }

    static var temp: String {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
    }
}

final class ScanSession: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        if Task.isCancelled { return true }
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }

    /// Sizes are measured in-process so a security-scoped home folder still counts.
    func du(path: String, depth: Int) -> [String: Int64] {
        if isCancelled { return [:] }
        let root = URL(fileURLWithPath: path)
        if (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { return [:] }
        guard FileManager.default.fileExists(atPath: path) else { return [:] }
        if depth <= 0 {
            let bytes = treeBytes(root)
            guard !isCancelled, bytes > 0 else { return [:] }
            return [path: bytes]
        }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else { return [:] }
        var sizes: [String: Int64] = [:]
        for child in children {
            if isCancelled { return [:] }
            if (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { continue }
            let bytes = treeBytes(child)
            if isCancelled { return [:] }
            if bytes > 0 { sizes[child.path] = bytes }
        }
        return sizes
    }

    private func treeBytes(_ url: URL) -> Int64 {
        guard !isCancelled else { return 0 }
        let keys: Set<URLResourceKey> = [
            .isSymbolicLinkKey, .isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true else { return 0 }
        let own = allocated(values)
        if values.isDirectory != true { return own }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return own }
        var total = own
        var seen = 0
        for case let item as URL in enumerator {
            seen += 1
            if seen % 400 == 0, isCancelled { return 0 }
            let add: Int64 = autoreleasepool {
                guard let itemValues = try? item.resourceValues(forKeys: keys), itemValues.isSymbolicLink != true else { return 0 }
                return allocated(itemValues)
            }
            total += add
        }
        return isCancelled ? 0 : total
    }

    private func allocated(_ values: URLResourceValues) -> Int64 {
        if let size = values.totalFileAllocatedSize { return Int64(max(size, 0)) }
        if let size = values.fileAllocatedSize { return Int64(max(size, 0)) }
        if let size = values.fileSize { return Int64(max(size, 0)) }
        return 0
    }
}

enum ScanEngine {
    static func scan() -> AsyncStream<ScanEvent> {
        let session = ScanSession()
        return AsyncStream { continuation in
            let task = Task.detached {
                let categories = session.collect { continuation.yield(.progress($0)) }
                continuation.yield(.done(categories))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                session.cancel()
                task.cancel()
            }
        }
    }
}

private struct RawItem {
    var name: String
    var detail: String
    var path: String
    var bytes: Int64
    var safety: Safety
    var selected: Bool
}

extension ScanSession {
    func collect(progress: @escaping @Sendable (String) -> Void) -> [CleanCategory] {
        let home = Locations.home
        let downloads = Locations.downloads
        let temp = Locations.temp
        var categories: [CleanCategory] = []

        func add(_ category: CleanCategory?) {
            if let category, !category.items.isEmpty { categories.append(category) }
        }

        progress("Measuring app caches")
        add(appCaches(home: home))
        if isCancelled { return categories }

        progress("Measuring browsers")
        add(browsers(home: home))
        if isCancelled { return categories }

        progress("Measuring developer tools")
        add(developer(home: home, progress: progress))
        add(goModules(home: home))
        if isCancelled { return categories }

        progress("Measuring Xcode")
        add(derivedData(home: home))
        add(deviceSupport(home: home))
        add(archives(home: home))
        if isCancelled { return categories }

        progress("Measuring logs")
        add(logs(home: home))
        if isCancelled { return categories }

        progress("Measuring Downloads")
        add(installers(home: home, downloads: downloads))
        if isCancelled { return categories }

        progress("Measuring temporary files")
        add(temporary(home: home, temp: temp))
        if isCancelled { return categories }

        progress("Measuring Trash")
        add(trash(home: home))
        return categories
    }

    private func appCaches(home: String) -> CleanCategory? {
        let root = home + "/Library/Caches"
        let sizes = du(path: root, depth: 1)
        let peeled = Browser.cacheFolderNames.union([
            "Homebrew", "CocoaPods", "pip", "Yarn", "pnpm",
            "org.swift.swiftpm", "com.apple.dt.Xcode", "go-build",
        ])
        var raws: [RawItem] = []
        for (path, bytes) in sizes {
            let name = URL(fileURLWithPath: path).lastPathComponent
            guard path != root, !peeled.contains(name), !name.hasPrefix("."), !name.hasSuffix(".app") else { continue }
            guard !isSymlink(path), bytes >= 128 * 1024 else { continue }
            let lower = name.lowercased()
            if ["password", "keychain", "cookie", "credential", "wallet", "secret", "token", "account", "session"].contains(where: { lower.contains($0) }) {
                continue
            }
            raws.append(RawItem(
                name: prettyCacheName(name),
                detail: Format.homePath(path, home: home),
                path: path,
                bytes: bytes,
                safety: .cacheChild,
                selected: true
            ))
        }
        return pack(
            id: "caches",
            name: "App caches",
            blurb: "Files apps can recreate the next time they open.",
            symbol: "square.stack.3d.up",
            group: .ready,
            raws: raws,
            rollSmall: true
        )
    }

    private func browsers(home: String) -> CleanCategory? {
        var raws: [RawItem] = []
        let cacheRoot = home + "/Library/Caches"
        let sizes = du(path: cacheRoot, depth: 1)
        for (path, bytes) in sizes {
            let name = URL(fileURLWithPath: path).lastPathComponent
            guard Browser.cacheFolderNames.contains(name), bytes > 0, !isSymlink(path) else { continue }
            raws.append(RawItem(
                name: prettyCacheName(name),
                detail: Format.homePath(path, home: home),
                path: path,
                bytes: bytes,
                safety: .cacheChild,
                selected: true
            ))
        }

        let fm = FileManager.default
        for relative in Browser.supportRoots {
            let base = home + "/" + relative
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: base, isDirectory: &isDir), isDir.boolValue else { continue }
            let profiles = (try? fm.contentsOfDirectory(atPath: base)) ?? []
            for profile in profiles where Browser.isProfile(profile) {
                var paths: [(String, Int64)] = []
                for cache in ["Cache", "Code Cache", "GPUCache"] {
                    let path = base + "/" + profile + "/" + cache
                    if let bytes = singleSize(path), bytes > 0 { paths.append((path, bytes)) }
                }
                for cache in ["CacheStorage", "ScriptCache"] {
                    let path = base + "/" + profile + "/Service Worker/" + cache
                    if let bytes = singleSize(path), bytes > 0 { paths.append((path, bytes)) }
                }
                for (path, bytes) in paths {
                    let browser = URL(fileURLWithPath: base).lastPathComponent
                    raws.append(RawItem(
                        name: "\(browser) · \(profile)",
                        detail: Format.homePath(path, home: home),
                        path: path,
                        bytes: bytes,
                        safety: .browserProfileCache,
                        selected: true
                    ))
                }
            }
        }
        return pack(
            id: "browsers",
            name: "Browser caches",
            blurb: "Page and image caches. Sign-ins stay signed in.",
            symbol: "globe",
            group: .ready,
            raws: raws,
            rollSmall: true
        )
    }

    private func developer(home: String, progress: @escaping (String) -> Void) -> CleanCategory? {
        let pins: [Pinned] = [
            .npm, .pipLibrary, .pipHome, .brew, .gradle, .cocoapods, .yarn, .yarnBerry,
            .pnpm, .pnpmLocal, .goBuild, .cargo, .swiftpm, .xcode, .simulator,
        ]
        var raws: [RawItem] = []
        for pin in pins {
            progress("Measuring \(pin.title)")
            if isCancelled { break }
            let path = pin.path(home: home)
            guard let bytes = singleSize(path), bytes >= 128 * 1024, !isSymlink(path) else { continue }
            raws.append(RawItem(
                name: pin.title,
                detail: Format.homePath(path, home: home),
                path: path,
                bytes: bytes,
                safety: .pinned(pin),
                selected: true
            ))
        }
        return pack(
            id: "developer",
            name: "Developer caches",
            blurb: "Package and tool caches. Project files are not touched.",
            symbol: "terminal",
            group: .ready,
            raws: raws,
            rollSmall: false
        )
    }

    private func goModules(home: String) -> CleanCategory? {
        let path = Pinned.goModules.path(home: home)
        guard let bytes = singleSize(path), bytes >= 128 * 1024, !isSymlink(path) else { return nil }
        let raw = RawItem(
            name: "Module cache",
            detail: Format.homePath(path, home: home),
            path: path,
            bytes: bytes,
            safety: .pinned(.goModules),
            selected: false
        )
        return pack(
            id: "gomod",
            name: "Go modules",
            blurb: "Downloaded modules. Projects stay, but the next build fetches them again.",
            symbol: "cube.box",
            group: .optional,
            raws: [raw],
            rollSmall: false
        )
    }

    private func derivedData(home: String) -> CleanCategory? {
        childrenCategory(
            id: "derived",
            root: home + "/Library/Developer/Xcode/DerivedData",
            name: "Xcode DerivedData",
            blurb: "Build products. The next build recreates them.",
            symbol: "hammer",
            group: .ready,
            safety: .derivedDataChild,
            selected: true,
            nameTransform: projectName
        )
    }

    private func deviceSupport(home: String) -> CleanCategory? {
        let roots = [
            home + "/Library/Developer/Xcode/iOS DeviceSupport",
            home + "/Library/Developer/Xcode/watchOS DeviceSupport",
            home + "/Library/Developer/Xcode/tvOS DeviceSupport",
        ]
        var raws: [RawItem] = []
        for root in roots {
            let kind = URL(fileURLWithPath: root).lastPathComponent.replacingOccurrences(of: " DeviceSupport", with: "")
            for (path, bytes) in du(path: root, depth: 1) where path != root && bytes > 0 && !isSymlink(path) {
                raws.append(RawItem(
                    name: "\(kind) · \(URL(fileURLWithPath: path).lastPathComponent)",
                    detail: Format.homePath(path, home: home),
                    path: path,
                    bytes: bytes,
                    safety: .deviceSupportChild,
                    selected: false
                ))
            }
        }
        return pack(
            id: "devices",
            name: "Device support",
            blurb: "Symbol files Xcode can download again when you plug a device in.",
            symbol: "iphone",
            group: .optional,
            raws: raws,
            rollSmall: true
        )
    }

    private func archives(home: String) -> CleanCategory? {
        childrenCategory(
            id: "archives",
            root: home + "/Library/Developer/Xcode/Archives",
            name: "Xcode archives",
            blurb: "Exported builds. Leave these if you still ship from them.",
            symbol: "archivebox",
            group: .optional,
            safety: .archiveChild,
            selected: false,
            nameTransform: { $0 }
        )
    }

    private func logs(home: String) -> CleanCategory? {
        childrenCategory(
            id: "logs",
            root: home + "/Library/Logs",
            name: "Logs",
            blurb: "Diagnostic and app logs.",
            symbol: "doc.text",
            group: .ready,
            safety: .logChild,
            selected: true,
            nameTransform: prettyCacheName,
            skip: { $0 == "Hedge" || $0.hasPrefix(".") }
        )
    }

    private func installers(home: String, downloads: String) -> CleanCategory? {
        guard downloads.hasPrefix(home + "/") else { return nil }
        let fm = FileManager.default
        let allowed = ["dmg", "pkg", "iso", "xip"]
        let urls = (try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: downloads),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        var raws: [RawItem] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
            guard values?.isSymbolicLink != true, values?.isRegularFile == true else { continue }
            guard allowed.contains(url.pathExtension.lowercased()) else { continue }
            guard let modified = values?.contentModificationDate, modified < cutoff else { continue }
            let bytes = Int64(values?.fileSize ?? 0)
            guard bytes > 0 else { continue }
            raws.append(RawItem(
                name: url.lastPathComponent,
                detail: Format.homePath(url.path, home: home),
                path: url.path,
                bytes: bytes,
                safety: .downloadsInstaller,
                selected: false
            ))
        }
        return pack(
            id: "installers",
            name: "Old installers",
            blurb: "Disk images and packages in Downloads, older than two weeks.",
            symbol: "shippingbox",
            group: .optional,
            raws: raws,
            rollSmall: false
        )
    }

    private func temporary(home: String, temp: String) -> CleanCategory? {
        if FolderAccess.isSandboxed { return nil }
        guard temp.hasPrefix("/private/var/folders/") || temp.hasPrefix("/var/folders/") else { return nil }
        let cutoff = Date().addingTimeInterval(-3 * 86_400)
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: temp),
            includingPropertiesForKeys: [.isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        )) ?? []
        var raws: [RawItem] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey])
            guard values?.isSymbolicLink != true else { continue }
            guard let modified = values?.contentModificationDate, modified < cutoff else { continue }
            guard let bytes = singleSize(url.path), bytes >= 128 * 1024 else { continue }
            raws.append(RawItem(
                name: url.lastPathComponent,
                detail: "Older than three days",
                path: url.path,
                bytes: bytes,
                safety: .tempChild,
                selected: false
            ))
        }
        return pack(
            id: "temp",
            name: "Temporary files",
            blurb: "Left in the system temp folder for more than three days.",
            symbol: "clock",
            group: .optional,
            raws: raws,
            rollSmall: true
        )
    }

    private func trash(home: String) -> CleanCategory? {
        childrenCategory(
            id: "trash",
            root: home + "/.Trash",
            name: "Trash",
            blurb: "Already in Trash. Emptying this cannot be undone.",
            symbol: "trash",
            group: .permanent,
            safety: .trashChild,
            selected: false,
            nameTransform: { $0 },
            minimum: 1
        )
    }

    private func childrenCategory(
        id: String,
        root: String,
        name: String,
        blurb: String,
        symbol: String,
        group: CleanGroup,
        safety: Safety,
        selected: Bool,
        nameTransform: (String) -> String,
        skip: (String) -> Bool = { $0.hasPrefix(".") },
        minimum: Int64 = 128 * 1024
    ) -> CleanCategory? {
        let home = Locations.home
        var raws: [RawItem] = []
        for (path, bytes) in du(path: root, depth: 1) {
            let item = URL(fileURLWithPath: path).lastPathComponent
            guard path != root, bytes >= minimum, !skip(item), !isSymlink(path) else { continue }
            raws.append(RawItem(
                name: nameTransform(item),
                detail: Format.homePath(path, home: home),
                path: path,
                bytes: bytes,
                safety: safety,
                selected: selected
            ))
        }
        return pack(id: id, name: name, blurb: blurb, symbol: symbol, group: group, raws: raws, rollSmall: true)
    }

    private func singleSize(_ path: String) -> Int64? {
        let sizes = du(path: path, depth: 0)
        if let exact = sizes[path] { return exact }
        return sizes.values.first
    }

    private func isSymlink(_ path: String) -> Bool {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isSymbolicLinkKey])
        return values?.isSymbolicLink == true
    }

    private func pack(
        id: String,
        name: String,
        blurb: String,
        symbol: String,
        group: CleanGroup,
        raws: [RawItem],
        rollSmall: Bool
    ) -> CleanCategory? {
        let items = packItems(raws, category: id, rollSmall: rollSmall)
        guard !items.isEmpty else { return nil }
        return CleanCategory(id: id, name: name, blurb: blurb, symbol: symbol, group: group, items: items)
    }

    private func packItems(_ raws: [RawItem], category: String, rollSmall: Bool) -> [CleanItem] {
        let sorted = raws.sorted { $0.bytes > $1.bytes }
        guard rollSmall else { return sorted.map { CleanItem(category: category, raw: $0) } }
        var large: [CleanItem] = []
        var small: [Safety: [RawItem]] = [:]
        for raw in sorted {
            if raw.bytes >= 8_000_000 {
                large.append(CleanItem(category: category, raw: raw))
            } else {
                small[raw.safety, default: []].append(raw)
            }
        }
        var rollups: [CleanItem] = []
        for (_, group) in small {
            if group.count == 1, let only = group.first {
                large.append(CleanItem(category: category, raw: only))
            } else if !group.isEmpty {
                let paths = group.map { CleanPath(path: $0.path, bytes: $0.bytes) }
                rollups.append(CleanItem(
                    id: category + "-small-" + String(describing: group[0].safety),
                    name: "Smaller leftovers",
                    detail: "\(group.count) items under 8 MB",
                    paths: paths,
                    selected: group.allSatisfy(\.selected),
                    safety: group[0].safety
                ))
            }
        }
        rollups.sort { $0.bytes > $1.bytes }
        return large.sorted { $0.bytes > $1.bytes } + rollups
    }
}

extension CleanItem {
    fileprivate init(category: String, raw: RawItem) {
        self.init(
            id: category + ":" + raw.path,
            name: raw.name,
            detail: raw.detail,
            paths: [CleanPath(path: raw.path, bytes: raw.bytes)],
            selected: raw.selected,
            safety: raw.safety
        )
    }
}

private func prettyCacheName(_ raw: String) -> String {
    let known = [
        "com.apple.Safari": "Safari",
        "com.apple.dt.Xcode": "Xcode",
        "com.microsoft.VSCode": "VS Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "company.thebrowser.Browser": "Arc",
        "com.kagi.kagimacOS": "Orion",
        "com.hnc.Discord": "Discord",
        "com.tinyspeck.slackmacgap": "Slack",
        "Google": "Google Chrome",
        "BraveSoftware": "Brave",
        "Firefox": "Firefox",
        "Microsoft Edge": "Edge",
    ]
    if let known = known[raw] { return known }
    let boring: Set<String> = ["client", "helper", "mac", "macos", "desktop", "agent", "service", "browser"]
    let parts = raw.split(separator: ".").map(String.init)
    if parts.count >= 2, ["com", "org", "net", "io", "app"].contains(parts[0].lowercased()) {
        let body = parts.dropFirst()
        if let last = body.last?.lowercased(), boring.contains(last), body.count >= 2 {
            return capitalize(String(body.dropLast().last ?? ""))
        }
        return capitalize(String(body.last ?? raw))
    }
    return raw
}

private func capitalize(_ text: String) -> String {
    guard let first = text.first else { return text }
    return first.uppercased() + text.dropFirst()
}

private func projectName(_ raw: String) -> String {
    guard let range = raw.range(of: #"-[A-Za-z0-9]{8,}$"#, options: .regularExpression) else { return raw }
    let trimmed = raw[..<range.lowerBound]
    return trimmed.isEmpty ? raw : String(trimmed)
}

enum Cleaner {
    static func remove(path: String, safety: Safety) -> RemoveOutcome {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return .missing }
        if (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            return .refused
        }
        let resolved = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        let home = Locations.home
        let downloads = Locations.downloads
        let temp = Locations.temp
        guard DeletionGuard.approve(resolved, safety: safety, home: home, downloads: downloads, temp: temp) else {
            return .refused
        }
        let bundle = Bundle.main.bundlePath
        if bundle.hasPrefix(resolved) {
            return .refused
        }
        let url = URL(fileURLWithPath: resolved)
        do {
            if safety == .trashChild {
                guard resolved.hasPrefix(home + "/.Trash/") else { return .refused }
                try fm.removeItem(at: url)
            } else {
                try fm.trashItem(at: url, resultingItemURL: nil)
            }
            return .removed
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

enum ActivityLog {
    static var directory: URL {
        if FolderAccess.isSandboxed {
            let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            return library.appendingPathComponent("Logs/Hedge", isDirectory: true)
        }
        return URL(fileURLWithPath: Locations.home, isDirectory: true)
            .appendingPathComponent("Library/Logs/Hedge", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("activity.log")
    }

    static var blurb: String {
        FolderAccess.isSandboxed
            ? "A short log stays with Hedge on this Mac."
            : "A short log lives in ~/Library/Logs/Hedge."
    }

    static func load() -> [ActivityEntry] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let formatter = ISO8601DateFormatter()
        var entries: [ActivityEntry] = []
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 6, fields[0] == "S" else { continue }
            guard let date = formatter.date(from: fields[1]), let bytes = Int64(fields[2]) else { continue }
            entries.append(ActivityEntry(
                id: UUID(),
                date: date,
                title: unescape(fields[4]),
                detail: unescape(fields[5]),
                bytes: bytes,
                ok: fields[3] == "1"
            ))
        }
        return Array(entries.suffix(80).reversed())
    }

    static func append(entry: ActivityEntry, paths: [String]) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let time = formatter.string(from: entry.date)
        var lines = ["S\t\(time)\t\(entry.bytes)\t\(entry.ok ? "1" : "0")\t\(escape(entry.title))\t\(escape(entry.detail))\n"]
        for path in paths {
            lines.append("P\t\(time)\t\(escape(path))\n")
        }
        let data = lines.joined().data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: fileURL)
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\\\", with: "\\")
    }
}

enum HealthProbe {
    struct Reading: Sendable {
        var snapshot: HealthSnapshot
        var cpu: CPUSample?
        var memories: [Int32: UInt64]
    }

    static func disk() -> (free: Int64, total: Int64) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return (0, 0) }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        return (free, total)
    }

    static func measure(previous: CPUSample?) -> Reading {
        var snapshot = HealthSnapshot()
        let disk = disk()
        snapshot.diskFree = disk.free
        snapshot.diskTotal = disk.total
        snapshot.uptime = ProcessInfo.processInfo.systemUptime
        snapshot.memoryTotal = ProcessInfo.processInfo.physicalMemory

        var load = [Double](repeating: 0, count: 3)
        if getloadavg(&load, 3) == 3 {
            snapshot.load1 = load[0]
            snapshot.load5 = load[1]
            snapshot.load15 = load[2]
        }

        let sample = cpuSample()
        if let sample, let previous {
            let user = delta(sample.user, previous.user)
            let system = delta(sample.system, previous.system)
            let nice = delta(sample.nice, previous.nice)
            let idle = delta(sample.idle, previous.idle)
            let total = user + system + nice + idle
            if total > 0 {
                snapshot.cpu = Double(user + system + nice) / Double(total)
            }
        }

        applyMemory(&snapshot)
        snapshot.swapUsed = swapUsage()
        snapshot.thermal = ThermalLevel(ProcessInfo.processInfo.thermalState)
        let listed = processList()
        var memories: [Int32: UInt64] = [:]
        memories.reserveCapacity(listed.count)
        for row in listed {
            memories[Int32(row.id)] = row.memory
        }
        snapshot.processes = Array(listed.lazy.filter { $0.memory > 0 }.prefix(7))
        return Reading(snapshot: snapshot, cpu: sample, memories: memories)
    }

    private static func delta(_ current: UInt32, _ previous: UInt32) -> UInt64 {
        if current >= previous { return UInt64(current - previous) }
        return UInt64(UInt32.max - previous) + UInt64(current) + 1
    }

    private static func cpuSample() -> CPUSample? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUSample(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
        )
    }

    private static func applyMemory(_ snapshot: inout HealthSnapshot) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)
        func pages(_ value: UInt64) -> UInt64 { value * page }
        let purgeable = UInt64(stats.purgeable_count)
        let internalPages = UInt64(stats.internal_page_count)
        let appPages = internalPages > purgeable ? internalPages - purgeable : 0
        snapshot.memoryApp = pages(appPages)
        snapshot.memoryWired = pages(UInt64(stats.wire_count))
        snapshot.memoryCompressed = pages(UInt64(stats.compressor_page_count))
        snapshot.memoryCached = pages(purgeable + UInt64(stats.external_page_count))
        snapshot.memoryFree = pages(UInt64(stats.free_count) + UInt64(stats.speculative_count))
        snapshot.memoryUsed = snapshot.memoryApp + snapshot.memoryWired + snapshot.memoryCompressed
    }

    private static func swapUsage() -> UInt64? {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = withUnsafeMutablePointer(to: &swap) { pointer in
            sysctlbyname("vm.swapusage", pointer, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return swap.xsu_used
    }

    private static func processList() -> [ProcessRow] {
        let native = processListFromLibproc()
        if native.contains(where: { $0.memory > 0 }) {
            return native.sorted { $0.memory > $1.memory }
        }
        let fallback = processListFromPS()
        if fallback.contains(where: { $0.memory > 0 }) {
            return fallback.sorted { $0.memory > $1.memory }
        }
        return native.sorted { $0.memory > $1.memory }
    }

    private static func processListFromLibproc() -> [ProcessRow] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }
        let slots = Int(needed) / MemoryLayout<pid_t>.stride + 8
        var pids = [pid_t](repeating: 0, count: slots)
        let written = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return proc_listpids(UInt32(PROC_ALL_PIDS), 0, base, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard written > 0 else { return [] }
        let available = min(pids.count, Int(written) / MemoryLayout<pid_t>.stride)
        var rows: [ProcessRow] = []
        rows.reserveCapacity(available)
        for pid in pids.prefix(available) {
            let name = processName(pid)
            guard !name.isEmpty else { continue }
            rows.append(ProcessRow(id: Int(pid), name: name, memory: resident(pid)))
        }
        return rows
    }

    private static func resident(_ pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = withUnsafeMutableBytes(of: &info) { raw in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, raw.baseAddress, Int32(MemoryLayout<proc_taskinfo>.stride))
        }
        guard size == Int32(MemoryLayout<proc_taskinfo>.stride) else { return 0 }
        return info.pti_resident_size
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = buffer.withUnsafeMutableBufferPointer { raw -> Int32 in
            guard let base = raw.baseAddress else { return 0 }
            return proc_name(pid, base, UInt32(raw.count))
        }
        guard length > 0 else { return "" }
        let name = String(cString: buffer)
        if name.contains("/") {
            return URL(fileURLWithPath: name).lastPathComponent
        }
        return name
    }

    private static func processListFromPS() -> [ProcessRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-arcwwwxo", "pid=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var rows: [ProcessRow] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let pidText = trimmed[..<first].trimmingCharacters(in: .whitespaces)
            let rest = trimmed[trimmed.index(after: first)...].trimmingCharacters(in: .whitespaces)
            guard let second = rest.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let rss = rest[..<second].trimmingCharacters(in: .whitespaces)
            var name = String(rest[rest.index(after: second)...].trimmingCharacters(in: .whitespaces))
            guard let pid = Int32(pidText), let kb = UInt64(rss), kb > 0, !name.isEmpty else { continue }
            if name.contains("/") { name = URL(fileURLWithPath: name).lastPathComponent }
            rows.append(ProcessRow(id: Int(pid), name: name, memory: kb * 1024))
        }
        return rows
    }
}
