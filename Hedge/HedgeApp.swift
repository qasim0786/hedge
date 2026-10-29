import SwiftUI

@main
struct HedgeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: 1120, minHeight: 720)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1220, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Overview") { model.page = .overview }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Health") { model.page = .health }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Memory") { model.page = .memory }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Temperature") { model.page = .temperature }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Security") { model.page = .security }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Activity") { model.page = .activity }
                    .keyboardShortcut("6", modifiers: .command)
            }
            CommandMenu("Clean") {
                Button(model.needsAccess ? "Allow Home Folder" : (model.phase == .scanning ? "Stop Scan" : "Scan Again")) {
                    if model.needsAccess {
                        model.allowHomeFolder()
                    } else if model.phase == .scanning {
                        model.stopScan()
                    } else {
                        model.startScan()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.phase == .cleaning)

                Button("Run Security Check") {
                    model.page = .security
                    model.startSecurity()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Trim Selected") {
                    model.askToTrim()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.phase != .ready || model.selectedBytes == 0)
            }
            CommandMenu("Support") {
                Button("Donate") { model.showDonate = true }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Technospike Website") { Support.openSite() }
                Button("Email Technospike") { Support.openMail() }
            }
        }
    }
}
