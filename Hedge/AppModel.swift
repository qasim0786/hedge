import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var page: Page = .overview
    var phase: Phase = .scanning
    var categories: [CleanCategory] = []
    var selectedCategoryID: String?
    var progress = "Starting"
    var notice: String?
    var accessNote: String?
    var showConfirm = false
    var showDonate = false
    var health = HealthSnapshot()
    var activity: [ActivityEntry] = []
    var needsAccess = false
    var apps: [QuitApp] = []
    var quitSelection: Set<String> = []
    var showQuitConfirm = false
    var quitting = false
    var memoryNote: String?
    var memoryPressure: MemoryPressure = .unknown
    var pulse: [Pulse] = []
    var checks: [SecurityCheck] = []
    var securityBusy = false
    var securityChecked: Date?

    private var healthTask: Task<Void, Never>?
    private var workTask: Task<Void, Never>?
    private var pressureSource: (any DispatchSourceMemoryPressure)?
    private var scanGeneration = 0
    private var previousCPU: CPUSample?

    init() {
        let disk = HealthProbe.disk()
        health.diskFree = disk.free
        health.diskTotal = disk.total
        activity = ActivityLog.load()
        let granted = FolderAccess.restore()
        needsAccess = FolderAccess.isSandboxed && !granted
        if needsAccess { phase = .ready }
        startHealth()
        watchPressure()
        if !needsAccess { startScan() }
    }

    var foundBytes: Int64 {
        categories.reduce(0) { $0 + $1.bytes }
    }

    var selectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.selectedBytes }
    }

    var selectedCategory: CleanCategory? {
        categories.first { $0.id == selectedCategoryID } ?? categories.first
    }

    var confirmPlans: [RemovalPlan] {
        categories.flatMap { category in
            category.items.filter(\.selected).map {
                RemovalPlan(name: $0.name, paths: $0.paths, safety: $0.safety)
            }
        }
    }

    var permanentBytes: Int64 {
        confirmPlans.filter { $0.safety == .trashChild }.reduce(0) { $0 + $1.paths.reduce(0) { $0 + $1.bytes } }
    }

    var permanentPlaces: Int {
        confirmPlans.filter { $0.safety == .trashChild }.reduce(0) { $0 + $1.paths.count }
    }

    var selectedPlaces: Int {
        confirmPlans.reduce(0) { $0 + $1.paths.count }
    }

    var quitPlans: [QuitApp] {
        apps.filter { quitSelection.contains($0.id) }
    }

    var quitBytes: UInt64 {
        quitPlans.reduce(0) { $0 + $1.memory }
    }

    func toggleCategory(_ id: String) {
        var next = categories
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        let turnOn = !next[index].allSelected
        for item in next[index].items.indices {
            next[index].items[item].selected = turnOn
        }
        categories = next
    }

    func toggleItem(category: String, item: String) {
        var next = categories
        guard let categoryIndex = next.firstIndex(where: { $0.id == category }),
              let itemIndex = next[categoryIndex].items.firstIndex(where: { $0.id == item })
        else { return }
        next[categoryIndex].items[itemIndex].selected.toggle()
        categories = next
    }

    func allowHomeFolder() {
        guard let url = FolderAccess.chooseHome() else { return }
        let chosen = url.resolvingSymlinksInPath().standardizedFileURL.path
        let home = URL(fileURLWithPath: Locations.home).resolvingSymlinksInPath().standardizedFileURL.path
        guard chosen == home else {
            accessNote = "Choose the home folder itself, the one named for this account."
            return
        }
        guard FolderAccess.persist(url) else {
            accessNote = "macOS didn’t keep that permission. Try again."
            return
        }
        accessNote = nil
        needsAccess = false
        if !checks.isEmpty {
            var next = checks.filter { $0.id != "access" }
            next.insert(FolderAccess.accessCheck(granted: true), at: 0)
            checks = next
        }
        startScan()
    }

    func startScan() {
        guard phase != .cleaning else { return }
        if FolderAccess.isSandboxed && !FolderAccess.canReadCaches {
            needsAccess = true
            phase = .ready
            accessNote = "Hedge still can’t read caches. Choose the home folder again."
            return
        }
        scanGeneration += 1
        let generation = scanGeneration
        workTask?.cancel()
        phase = .scanning
        progress = "Starting"
        let stream = ScanEngine.scan()
        workTask = Task {
            for await event in stream {
                guard generation == self.scanGeneration else { return }
                switch event {
                case .progress(let text):
                    self.progress = text
                case .done(let found):
                    self.categories = found
                    if self.selectedCategoryID == nil || found.contains(where: { $0.id == self.selectedCategoryID }) == false {
                        self.selectedCategoryID = found.max { $0.bytes < $1.bytes }?.id
                    }
                    self.phase = .ready
                }
            }
            if generation == self.scanGeneration, self.phase == .scanning {
                self.phase = .ready
            }
        }
    }

    func stopScan() {
        scanGeneration += 1
        workTask?.cancel()
        phase = .ready
        progress = "Stopped"
    }

    func askToTrim() {
        guard phase == .ready, selectedBytes > 0 else { return }
        showConfirm = true
    }

    func confirmTrim() {
        let plans = confirmPlans
        showConfirm = false
        guard !plans.isEmpty else { return }
        phase = .cleaning
        progress = "Trimming"
        workTask?.cancel()
        workTask = Task {
            var freed: Int64 = 0
            var removed = 0
            var failures: [String] = []
            var removedPaths: [String] = []
            for plan in plans {
                self.progress = plan.name
                var planFreed: Int64 = 0
                var planRemoved = 0
                for item in plan.paths {
                    if Task.isCancelled { break }
                    let outcome = await Task.detached {
                        Cleaner.remove(path: item.path, safety: plan.safety)
                    }.value
                    switch outcome {
                    case .removed:
                        planFreed += item.bytes
                        planRemoved += 1
                        removedPaths.append(item.path)
                    case .missing:
                        break
                    case .refused:
                        failures.append("\(plan.name) was left in place")
                    case .failed(let message):
                        failures.append("\(plan.name): \(message)")
                    }
                }
                freed += planFreed
                removed += planRemoved
            }

            let title: String
            let detail: String
            if removed == 0 {
                title = "Nothing was removed"
                detail = failures.first ?? "Those items were already gone or could not be changed."
            } else if plans.allSatisfy({ $0.safety == .trashChild }) {
                title = "Emptied \(Format.bytes(freed))"
                detail = "\(removed) items deleted from Trash."
            } else {
                title = "Trimmed \(Format.bytes(freed))"
                detail = failures.isEmpty
                    ? "\(removed) items moved to Trash."
                    : "\(removed) items moved to Trash. \(failures.count) left in place."
            }
            let entry = ActivityEntry(id: UUID(), date: Date(), title: title, detail: detail, bytes: freed, ok: failures.isEmpty && removed > 0)
            ActivityLog.append(entry: entry, paths: removedPaths)
            self.activity.insert(entry, at: 0)
            self.notice = title
            self.phase = .ready
            self.startScan()
        }
    }

    func toggleQuit(_ id: String) {
        var next = quitSelection
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        quitSelection = next
    }

    func selectAllQuit() {
        quitSelection = Set(apps.map(\.id))
    }

    func clearQuit() {
        quitSelection = []
    }

    func askToQuit() {
        guard !quitting, !quitPlans.isEmpty else { return }
        showQuitConfirm = true
    }

    func confirmQuit() {
        let plans = quitPlans
        showQuitConfirm = false
        guard !plans.isEmpty, !quitting else { return }
        quitting = true
        var asked = 0
        var bytes: UInt64 = 0
        var skipped: [String] = []
        for plan in plans {
            guard let running = NSRunningApplication(processIdentifier: plan.pid), !running.isTerminated else { continue }
            if running.terminate() {
                asked += 1
                bytes += plan.memory
            } else {
                skipped.append(plan.name)
            }
        }
        var selection = quitSelection
        for plan in plans { selection.remove(plan.id) }
        quitSelection = selection
        quitting = false

        let title: String
        let detail: String
        if asked == 0 {
            title = "Couldn’t ask those apps to quit"
            detail = "macOS didn’t allow that. Activity Monitor can close them."
        } else if skipped.isEmpty {
            title = "Asked \(asked) \(asked == 1 ? "app" : "apps") to quit"
            detail = bytes > 0
                ? "About \(Format.bytes(Int64(bytes))) can return once they close. They may ask you to save."
                : "They may ask you to save before closing."
        } else {
            title = "Asked \(asked) \(asked == 1 ? "app" : "apps") to quit"
            detail = "\(skipped.count) couldn’t be asked. About \(Format.bytes(Int64(bytes))) can return from the rest."
        }
        let entry = ActivityEntry(id: UUID(), date: Date(), title: title, detail: detail, bytes: 0, ok: asked > 0)
        ActivityLog.append(entry: entry, paths: [])
        activity.insert(entry, at: 0)
        memoryNote = title
    }

    func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    func startSecurity() {
        guard !securityBusy else { return }
        securityBusy = true
        Task {
            let found = await Task.detached {
                SecurityProbe.inspect()
            }.value
            self.checks = [FolderAccess.accessCheck(granted: !self.needsAccess)] + found
            self.securityChecked = Date()
            self.securityBusy = false
        }
    }

    private func startHealth() {
        healthTask?.cancel()
        healthTask = Task {
            while !Task.isCancelled {
                let previous = self.previousCPU
                let reading = await Task.detached {
                    HealthProbe.measure(previous: previous)
                }.value
                if Task.isCancelled { return }
                self.previousCPU = reading.cpu ?? previous
                self.health = reading.snapshot
                self.apps = QuitList.current(memory: reading.memories)
                let visible = Set(self.apps.map(\.id))
                let pruned = self.quitSelection.intersection(visible)
                if pruned != self.quitSelection {
                    self.quitSelection = pruned
                }
                self.recordPulse(reading.snapshot)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func recordPulse(_ snapshot: HealthSnapshot) {
        guard let cpu = snapshot.cpu, let thermal = snapshot.thermal else { return }
        var next = pulse
        next.append(Pulse(id: (next.last?.id ?? 0) + 1, cpu: cpu, thermal: thermal))
        if next.count > 120 {
            next.removeFirst(next.count - 120)
        }
        pulse = next
    }

    private func watchPressure() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            let event = source.data
            let next: MemoryPressure
            if event.contains(.critical) {
                next = .critical
            } else if event.contains(.warning) {
                next = .warning
            } else {
                next = .normal
            }
            Task { @MainActor in
                self?.memoryPressure = next
            }
        }
        source.resume()
        pressureSource = source
    }
}
