import Foundation

enum Page: String, CaseIterable, Identifiable {
    case overview
    case health
    case memory
    case temperature
    case security
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .health: "Health"
        case .memory: "Memory"
        case .temperature: "Temperature"
        case .security: "Security"
        case .activity: "Activity"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "leaf"
        case .health: "waveform.path.ecg"
        case .memory: "memorychip"
        case .temperature: "thermometer.medium"
        case .security: "checkmark.shield"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

enum Phase: Equatable {
    case scanning
    case ready
    case cleaning
}

enum CleanGroup: String, Sendable, CaseIterable {
    case ready
    case optional
    case permanent

    var title: String {
        switch self {
        case .ready: "Ready"
        case .optional: "Optional"
        case .permanent: "Permanent"
        }
    }
}

enum Pinned: String, Sendable, Hashable {
    case npm
    case pipLibrary
    case pipHome
    case brew
    case gradle
    case cocoapods
    case yarn
    case yarnBerry
    case pnpm
    case pnpmLocal
    case goBuild
    case goModules
    case cargo
    case swiftpm
    case xcode
    case simulator

    func path(home: String) -> String {
        switch self {
        case .npm: home + "/.npm/_cacache"
        case .pipLibrary: home + "/Library/Caches/pip"
        case .pipHome: home + "/.cache/pip"
        case .brew: home + "/Library/Caches/Homebrew"
        case .gradle: home + "/.gradle/caches"
        case .cocoapods: home + "/Library/Caches/CocoaPods"
        case .yarn: home + "/Library/Caches/Yarn"
        case .yarnBerry: home + "/.yarn/berry/cache"
        case .pnpm: home + "/Library/pnpm/store"
        case .pnpmLocal: home + "/.local/share/pnpm/store"
        case .goBuild: home + "/Library/Caches/go-build"
        case .goModules: home + "/go/pkg/mod"
        case .cargo: home + "/.cargo/registry/cache"
        case .swiftpm: home + "/Library/Caches/org.swift.swiftpm"
        case .xcode: home + "/Library/Caches/com.apple.dt.Xcode"
        case .simulator: home + "/Library/Developer/CoreSimulator/Caches"
        }
    }

    var title: String {
        switch self {
        case .npm: "npm"
        case .pipLibrary, .pipHome: "pip"
        case .brew: "Homebrew"
        case .gradle: "Gradle"
        case .cocoapods: "CocoaPods"
        case .yarn, .yarnBerry: "Yarn"
        case .pnpm, .pnpmLocal: "pnpm"
        case .goBuild: "Go build cache"
        case .goModules: "Go modules"
        case .cargo: "Cargo"
        case .swiftpm: "Swift packages"
        case .xcode: "Xcode cache"
        case .simulator: "Simulator caches"
        }
    }
}

enum Safety: Sendable, Hashable {
    case cacheChild
    case logChild
    case trashChild
    case downloadsInstaller
    case derivedDataChild
    case deviceSupportChild
    case archiveChild
    case tempChild
    case pinned(Pinned)
    case browserProfileCache
}

struct CleanPath: Sendable, Hashable, Identifiable {
    var id: String { path }
    let path: String
    let bytes: Int64
}

struct CleanItem: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let paths: [CleanPath]
    var selected: Bool
    let safety: Safety

    var bytes: Int64 { paths.reduce(0) { $0 + $1.bytes } }
}

struct CleanCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let group: CleanGroup
    var items: [CleanItem]

    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var selectedBytes: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.bytes } }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.selected) }
    var someSelected: Bool { items.contains(where: \.selected) }
}

struct ProcessRow: Identifiable, Sendable {
    let id: Int
    let name: String
    let memory: UInt64
}

struct QuitApp: Identifiable, Sendable, Equatable {
    var id: String { bundleID ?? "pid:\(pid)" }
    let pid: Int32
    let name: String
    let bundleID: String?
    let memory: UInt64
}

enum ThermalLevel: Int, Sendable {
    case nominal
    case fair
    case serious
    case critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }

    var title: String {
        switch self {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Throttling"
        }
    }

    var detail: String {
        switch self {
        case .nominal: "Comfortable. macOS hasn’t asked the machine to slow down."
        case .fair: "A little warm. Still inside what macOS expects."
        case .serious: "macOS is slowing work to bring the temperature down."
        case .critical: "macOS is throttling hard. Close heavy apps and let it breathe."
        }
    }
}

enum MemoryPressure: Sendable {
    case unknown
    case normal
    case warning
    case critical
}

struct HealthSnapshot: Sendable {
    var cpu: Double?
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var memoryApp: UInt64 = 0
    var memoryWired: UInt64 = 0
    var memoryCompressed: UInt64 = 0
    var memoryCached: UInt64 = 0
    var memoryFree: UInt64 = 0
    var swapUsed: UInt64?
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var uptime: TimeInterval = 0
    var thermal: ThermalLevel?
    var processes: [ProcessRow] = []
}

struct Pulse: Identifiable, Sendable {
    let id: Int
    var cpu: Double
    var thermal: ThermalLevel
}

enum SecurityState: Sendable {
    case pass
    case attention
    case unknown

    var label: String {
        switch self {
        case .pass: "in good shape"
        case .attention: "worth a look"
        case .unknown: "unread"
        }
    }
}

struct SecurityCheck: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let state: SecurityState
    let settingsURL: String?
}

struct CPUSample: Sendable {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32
}

struct ActivityEntry: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let bytes: Int64
    let ok: Bool
}

struct RemovalPlan: Sendable {
    let name: String
    let paths: [CleanPath]
    let safety: Safety
}

enum ScanEvent: Sendable {
    case progress(String)
    case done([CleanCategory])
}

enum RemoveOutcome: Sendable {
    case removed
    case missing
    case refused
    case failed(String)
}

enum Format {
    static func bytes(_ bytes: Int64) -> String {
        let parts = parts(bytes)
        if parts.unit == "bytes" { return "\(parts.value) bytes" }
        return "\(parts.value) \(parts.unit)"
    }

    static func parts(_ bytes: Int64) -> (value: String, unit: String) {
        let units = ["bytes", "KB", "MB", "GB", "TB"]
        var value = Double(max(bytes, 0))
        var index = 0
        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        let text: String
        if index == 0 {
            text = String(Int(value))
        } else if value >= 10 {
            text = String(format: "%.0f", value)
        } else {
            text = String(format: "%.1f", value)
        }
        return (text, units[index])
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h up" }
        if hours > 0 { return "\(hours)h \(minutes)m up" }
        return "\(minutes)m up"
    }

    static func when(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static var system: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static func homePath(_ path: String, home: String) -> String {
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
