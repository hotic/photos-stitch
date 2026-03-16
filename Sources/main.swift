import AppKit

@main
@MainActor
struct PhotosStitchApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.run()
    }
}
