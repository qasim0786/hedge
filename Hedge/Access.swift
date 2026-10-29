import AppKit
import Foundation

enum FolderAccess {
    private static let key = "homeBookmark"
    @MainActor private static var held: URL?

    nonisolated static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    nonisolated static var canReadCaches: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: Locations.home + "/Library/Caches")) != nil
    }

    @MainActor
    @discardableResult
    static func restore() -> Bool {
        guard isSandboxed else { return true }
        guard let data = UserDefaults.standard.data(forKey: key) else { return false }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return false }
        guard url.startAccessingSecurityScopedResource() else { return false }
        if stale, let fresh = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(fresh, forKey: key)
        }
        swapHeld(url)
        return true
    }

    @MainActor
    static func chooseHome() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Allow your home folder"
        panel.message = "Select the folder named for this account. Hedge measures caches there, and nothing is removed until you trim."
        panel.prompt = "Allow"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: Locations.home).deletingLastPathComponent()
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    @MainActor
    static func persist(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            url.stopAccessingSecurityScopedResource()
            return false
        }
        swapHeld(url)
        return true
    }

    @MainActor
    static func accessCheck(granted: Bool) -> SecurityCheck {
        if !isSandboxed {
            return SecurityCheck(
                id: "access",
                title: "Home folder",
                detail: "This copy can read the account directly.",
                state: .pass,
                settingsURL: nil
            )
        }
        if granted {
            return SecurityCheck(
                id: "access",
                title: "Home folder",
                detail: "Hedge can measure caches in your home folder.",
                state: .pass,
                settingsURL: nil
            )
        }
        return SecurityCheck(
            id: "access",
            title: "Home folder",
            detail: "Choose your home folder so caches can be measured.",
            state: .attention,
            settingsURL: nil
        )
    }

    @MainActor
    private static func swapHeld(_ url: URL) {
        if held?.path != url.path {
            held?.stopAccessingSecurityScopedResource()
        }
        held = url
    }
}
