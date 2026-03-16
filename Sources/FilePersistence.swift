import Foundation

enum FilePersistence {
    static func saveToDirectory(_ directory: URL, from url: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let destinationURL = uniqueURL(
            in: directory,
            preferredName: url.lastPathComponent
        )

        try moveItem(at: url, to: destinationURL)
        return destinationURL
    }

    static func preserveFailedOutput(from url: URL) throws -> URL {
        let destinationDirectory = try fallbackDirectory()
        let destinationURL = uniqueURL(
            in: destinationDirectory,
            preferredName: url.lastPathComponent
        )

        try moveItem(at: url, to: destinationURL)
        return destinationURL
    }

    static func preserveForTesting(from url: URL) throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let destinationDirectory: URL

        if let customDirectory = environment["PHOTOS_STITCH_OUTPUT_DIR"], !customDirectory.isEmpty {
            destinationDirectory = URL(fileURLWithPath: customDirectory, isDirectory: true)
        } else {
            destinationDirectory = try fallbackDirectory()
        }

        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let destinationURL = uniqueURL(
            in: destinationDirectory,
            preferredName: url.lastPathComponent
        )

        try moveItem(at: url, to: destinationURL)
        return destinationURL
    }

    private static func fallbackDirectory() throws -> URL {
        let picturesDirectory = try FileManager.default.url(
            for: .picturesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directoryName = L10n.string("file.fallback_directory")
        let destinationDirectory = picturesDirectory
            .appendingPathComponent(directoryName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        return destinationDirectory
    }

    private static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let fileManager = FileManager.default
        let baseName = (preferredName as NSString).deletingPathExtension
        let fileExtension = (preferredName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(preferredName)
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = "\(baseName)-\(counter)"
            let name = fileExtension.isEmpty ? suffix : "\(suffix).\(fileExtension)"
            candidate = directory.appendingPathComponent(name)
            counter += 1
        }

        return candidate
    }

    private static func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try? fileManager.removeItem(at: sourceURL)
        }
    }
}
