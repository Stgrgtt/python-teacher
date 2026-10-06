import AppKit
import SwiftUI

@main
struct PythonTeacherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model: AppModel

    init() {
        AppModel.migrateLegacyDefaults()
        try? KeychainStore().migrateLegacyItem()
        _model = StateObject(wrappedValue: AppModel(store: .migratingLegacyDirectory()))
    }

    var body: some Scene {
        Window("Python Teacher", id: "main") {
            WorkspaceView()
                .environmentObject(model)
                .tint(.teal)
                .onAppear {
                    delegate.model = model
                    model.upgradeExperience()
                }
        }
        .defaultSize(width: 1380, height: 900)
        .windowResizability(.contentMinSize)
        .commands {
            CodeEditorFindCommands()
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.settingsPresented = true }.keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Learning") {
                Button("Learn") { model.selectMode(.lesson) }.keyboardShortcut("1", modifiers: .command)
                Button("Practice") { model.selectMode(.practice) }.keyboardShortcut("2", modifiers: .command)
                Button("Assessment") { model.selectMode(.assessment) }.keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("Export current Python file…") { model.exportCode() }
                Button("Export learning backup…") { model.exportProgress() }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.cancelWork()
        model?.pauseFocusSession()
        model?.flushSave()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
