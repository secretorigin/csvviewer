import SwiftUI
import AppKit

@main
struct SQLoverCSVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var templateStore = TemplateStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(templateStore)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Открыть CSV…") { state.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Запрос") {
                Button("Выполнить") { state.runQuery() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(state.isRunning)
                Button("Экспортировать результат в CSV…") { state.exportResult() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!state.canExport)
            }
        }
    }
}

/// Гарантируем, что приложение запускается как обычное (regular) с активным окном,
/// даже при запуске через `swift run` без бандла.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
