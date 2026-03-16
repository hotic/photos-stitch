import Foundation
import UniformTypeIdentifiers

enum RequestSource: Sendable {
    case openFiles
    case commandLine
}

struct StitchRequest: Sendable {
    let urls: [URL]
    let source: RequestSource
}

struct StitchedImage: Sendable {
    let url: URL
    let format: UTType
    let preferredCreationDate: Date?
}

enum OutputDestination: Sendable {
    case photosLibrary
    case fileSystem(directory: URL)
}

struct UserFacingError: LocalizedError, Sendable {
    let title: String
    let message: String

    var errorDescription: String? {
        message
    }
}
