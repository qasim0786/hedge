import AppKit
import Foundation

enum SystemSettings {
    static let privacy = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
    static let lock = "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"
    static let users = "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension"
    static let sharing = "x-apple.systempreferences:com.apple.Sharing-Settings.extension"
    static let updates = "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
}

enum SecurityProbe {
    static func inspect() -> [SecurityCheck] {
        let work: [() -> SecurityCheck] = [
            fileVault, firewall, gatekeeper, sip, wakePassword,
            autoLogin, guest, remoteLogin, updates, xprotect,
        ]
        let lock = NSLock()
        let group = DispatchGroup()
        var results = [SecurityCheck?](repeating: nil, count: work.count)
        for (index, item) in work.enumerated() {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let check = item()
                lock.lock()
                results[index] = check
                lock.unlock()
                group.leave()
            }
        }
        group.wait()
        return results.compactMap { $0 }
    }

    private static func fileVault() -> SecurityCheck {
        let title = "FileVault"
        guard let text = Shell.text("/usr/bin/fdesetup", ["status"])?.lowercased() else {
            return unknown("filevault", title, SystemSettings.privacy)
        }
        if text.contains("filevault is on") {
            return SecurityCheck(id: "filevault", title: title, detail: "Your disk is encrypted with FileVault.", state: .pass, settingsURL: SystemSettings.privacy)
        }
        if text.contains("filevault is off") {
            return SecurityCheck(id: "filevault", title: title, detail: "FileVault is off. A lost Mac can be read from another computer.", state: .attention, settingsURL: SystemSettings.privacy)
        }
        return unknown("filevault", title, SystemSettings.privacy)
    }

    private static func firewall() -> SecurityCheck {
        let title = "Firewall"
        if let plist = dictionary(at: "/Library/Preferences/com.apple.alf.plist") {
            let raw = plist["globalstate"] ?? (plist["firewall"] as? [String: Any])?["globalstate"]
            if let number = number(raw) {
                if number == 0 {
                    return SecurityCheck(id: "firewall", title: title, detail: "The firewall is off.", state: .attention, settingsURL: SystemSettings.privacy)
                }
                let detail = number >= 2 ? "The firewall is on and blocking incoming connections." : "The firewall is on."
                return SecurityCheck(id: "firewall", title: title, detail: detail, state: .pass, settingsURL: SystemSettings.privacy)
            }
        }
        guard let text = Shell.text("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])?.lowercased() else {
            return unknown("firewall", title, SystemSettings.privacy)
        }
        if text.contains("disabled") || text.contains("state = 0") {
            return SecurityCheck(id: "firewall", title: title, detail: "The firewall is off.", state: .attention, settingsURL: SystemSettings.privacy)
        }
        if text.contains("enabled") || text.contains("state = 1") || text.contains("state = 2") {
            return SecurityCheck(id: "firewall", title: title, detail: "The firewall is on.", state: .pass, settingsURL: SystemSettings.privacy)
        }
        return unknown("firewall", title, SystemSettings.privacy)
    }

    private static func gatekeeper() -> SecurityCheck {
        let title = "Gatekeeper"
        guard let text = Shell.text("/usr/sbin/spctl", ["--status"])?.lowercased() else {
            return unknown("gatekeeper", title, SystemSettings.privacy)
        }
        if text.contains("disabled") {
            return SecurityCheck(id: "gatekeeper", title: title, detail: "Gatekeeper assessments are off.", state: .attention, settingsURL: SystemSettings.privacy)
        }
        if text.contains("enabled") {
            return SecurityCheck(id: "gatekeeper", title: title, detail: "Apps are checked before they open.", state: .pass, settingsURL: SystemSettings.privacy)
        }
        return unknown("gatekeeper", title, SystemSettings.privacy)
    }

    private static func sip() -> SecurityCheck {
        let title = "System Integrity Protection"
        guard let text = Shell.text("/usr/bin/csrutil", ["status"])?.lowercased() else {
            return unknown("sip", title, nil)
        }
        if text.contains("disabled") {
            return SecurityCheck(
                id: "sip",
                title: title,
                detail: "System Integrity Protection is off. Turning it back on is done from recovery.",
                state: .attention,
                settingsURL: nil
            )
        }
        if text.contains("enabled") {
            return SecurityCheck(id: "sip", title: title, detail: "System files are protected.", state: .pass, settingsURL: nil)
        }
        return unknown("sip", title, nil)
    }

    private static func wakePassword() -> SecurityCheck {
        let title = "Wake password"
        guard let plist = screensaverPlist() else {
            return unknown("wake", title, SystemSettings.lock)
        }
        guard let required = flag(plist["askForPassword"]) else {
            return SecurityCheck(
                id: "wake",
                title: title,
                detail: "A password is required when the display wakes.",
                state: .pass,
                settingsURL: SystemSettings.lock
            )
        }
        if !required {
            return SecurityCheck(
                id: "wake",
                title: title,
                detail: "The Mac can wake without a password.",
                state: .attention,
                settingsURL: SystemSettings.lock
            )
        }
        let delay = number(plist["askForPasswordDelay"]) ?? 0
        if delay > 3600 {
            return SecurityCheck(
                id: "wake",
                title: title,
                detail: "A password is required, but only after more than an hour.",
                state: .attention,
                settingsURL: SystemSettings.lock
            )
        }
        let detail = delay <= 0
            ? "A password is required as soon as the display wakes."
            : "A password is required \(delay) seconds after the display sleeps."
        return SecurityCheck(id: "wake", title: title, detail: detail, state: .pass, settingsURL: SystemSettings.lock)
    }

    private static func autoLogin() -> SecurityCheck {
        let title = "Automatic login"
        guard let plist = dictionary(at: "/Library/Preferences/com.apple.loginwindow.plist") else {
            return unknown("login", title, SystemSettings.users)
        }
        let user = (plist["autoLoginUser"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if user.isEmpty {
            return SecurityCheck(id: "login", title: title, detail: "This account isn’t signed in automatically.", state: .pass, settingsURL: SystemSettings.users)
        }
        return SecurityCheck(
            id: "login",
            title: title,
            detail: "Automatic login is on, so the desktop opens without a password.",
            state: .attention,
            settingsURL: SystemSettings.users
        )
    }

    private static func guest() -> SecurityCheck {
        let title = "Guest account"
        if let plist = dictionary(at: "/Library/Preferences/com.apple.loginwindow.plist"), let enabled = flag(plist["GuestEnabled"]) {
            if enabled {
                return SecurityCheck(id: "guest", title: title, detail: "The guest account can sign in.", state: .attention, settingsURL: SystemSettings.users)
            }
            return SecurityCheck(id: "guest", title: title, detail: "The guest account is off.", state: .pass, settingsURL: SystemSettings.users)
        }
        if let text = Shell.text("/usr/bin/dscl", [".", "-read", "/Users/Guest", "UserShell"])?.lowercased() {
            if text.contains("no such key") || text.contains("not found") || text.contains("eDSRecordNotFound".lowercased()) || text.contains("/usr/bin/false") {
                return SecurityCheck(id: "guest", title: title, detail: "The guest account is off.", state: .pass, settingsURL: SystemSettings.users)
            }
            if text.contains("/bin/") {
                return SecurityCheck(id: "guest", title: title, detail: "The guest account can sign in.", state: .attention, settingsURL: SystemSettings.users)
            }
        }
        return unknown("guest", title, SystemSettings.users)
    }

    private static func remoteLogin() -> SecurityCheck {
        let title = "Remote login"
        guard let text = Shell.text("/bin/launchctl", ["print", "system/com.openssh.sshd"])?.lowercased() else {
            return unknown("remote", title, SystemSettings.sharing)
        }
        if text.contains("could not find service") || text.contains("no such service") || text.contains("bad request") {
            return SecurityCheck(id: "remote", title: title, detail: "Remote login is off.", state: .pass, settingsURL: SystemSettings.sharing)
        }
        if text.contains("state = running") || text.contains("state = active") {
            return SecurityCheck(
                id: "remote",
                title: title,
                detail: "Remote login is on. Turn it off if you don’t use SSH.",
                state: .attention,
                settingsURL: SystemSettings.sharing
            )
        }
        return unknown("remote", title, SystemSettings.sharing)
    }

    private static func updates() -> SecurityCheck {
        let title = "System updates"
        guard let plist = dictionary(at: "/Library/Preferences/com.apple.SoftwareUpdate.plist"),
              let checks = flag(plist["AutomaticCheckEnabled"])
        else {
            return unknown("updates", title, SystemSettings.updates)
        }
        if checks {
            return SecurityCheck(id: "updates", title: title, detail: "Automatic update checks are on.", state: .pass, settingsURL: SystemSettings.updates)
        }
        return SecurityCheck(id: "updates", title: title, detail: "Automatic update checks are off.", state: .attention, settingsURL: SystemSettings.updates)
    }

    private static func xprotect() -> SecurityCheck {
        let title = "XProtect"
        let bundles = [
            "/Library/Apple/System/Library/CoreServices/XProtect.bundle",
            "/Library/Apple/System/Library/CoreServices/XProtect.app",
            "/System/Library/CoreServices/XProtect.bundle",
        ]
        for path in bundles {
            guard let plist = dictionary(at: path + "/Contents/Info.plist") else { continue }
            let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
            let detail = version.map { "Malware definitions are installed, version \($0)." } ?? "Malware definitions are installed."
            return SecurityCheck(id: "xprotect", title: title, detail: detail, state: .pass, settingsURL: SystemSettings.updates)
        }
        let parent = "/Library/Apple/System/Library/CoreServices"
        if FileManager.default.isReadableFile(atPath: parent), bundles.allSatisfy({ !FileManager.default.fileExists(atPath: $0) }) {
            return SecurityCheck(id: "xprotect", title: title, detail: "XProtect definitions weren’t found.", state: .attention, settingsURL: SystemSettings.updates)
        }
        return unknown("xprotect", title, SystemSettings.updates)
    }

    private static func screensaverPlist() -> [String: Any]? {
        let home = Locations.home
        var paths = [home + "/Library/Preferences/com.apple.screensaver.plist"]
        let byHost = home + "/Library/Preferences/ByHost"
        if let names = try? FileManager.default.contentsOfDirectory(atPath: byHost) {
            for name in names where name.hasPrefix("com.apple.screensaver") && name.hasSuffix(".plist") {
                paths.append(byHost + "/" + name)
            }
        }
        let loaded = paths.compactMap { dictionary(at: $0) }
        if let match = loaded.first(where: { $0["askForPassword"] != nil || $0["askForPasswordDelay"] != nil }) {
            return match
        }
        return loaded.first
    }

    private static func dictionary(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private static func flag(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        return nil
    }

    private static func number(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func unknown(_ id: String, _ title: String, _ settings: String?) -> SecurityCheck {
        SecurityCheck(
            id: id,
            title: title,
            detail: "Hedge couldn’t read this, so it isn’t guessing.",
            state: .unknown,
            settingsURL: settings
        )
    }
}

private enum Shell {
    static func text(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        do {
            try process.run()
        } catch {
            group.leave()
            return nil
        }
        if group.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 1)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
enum QuitList {
    private static let shielded: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.WindowManager",
        "com.apple.TextInputMenuAgent",
        "com.apple.Spotlight",
        "com.apple.coreservices.uiagent",
    ]

    static func current(memory: [Int32: UInt64]) -> [QuitApp] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.compactMap { app -> QuitApp? in
            guard app.activationPolicy == .regular else { return nil }
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
            if let bundle = app.bundleIdentifier {
                if bundle == own || shielded.contains(bundle) { return nil }
            }
            let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? ""
            guard !name.isEmpty else { return nil }
            return QuitApp(
                pid: app.processIdentifier,
                name: name,
                bundleID: app.bundleIdentifier,
                memory: memory[app.processIdentifier] ?? 0
            )
        }
        .sorted {
            if $0.memory != $1.memory { return $0.memory > $1.memory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        .prefix(30)
        .map { $0 }
    }
}
