import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
