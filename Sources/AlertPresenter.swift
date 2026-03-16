import AppKit

@MainActor
final class AlertPresenter {
    func showError(_ error: UserFacingError) {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.addButton(withTitle: L10n.string("alert.ok"))
        alert.runModal()
    }
}
