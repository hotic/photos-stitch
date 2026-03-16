import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = RequestCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let cliURLs = CommandLine.arguments
            .dropFirst()
            .map { URL(fileURLWithPath: $0) }

        if !cliURLs.isEmpty {
            coordinator.submit(urls: cliURLs, source: .commandLine)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        coordinator.submit(urls: urls, source: .openFiles)
    }
}
