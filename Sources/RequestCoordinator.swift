import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class RequestCoordinator {
    private let openFilesBatchWindowNanoseconds: UInt64 = 600_000_000
    private let iso8601Formatter = ISO8601DateFormatter()
    private let alertPresenter = AlertPresenter()
    private var pendingRequests: [StitchRequest] = []
    private var bufferedOpenFileURLs: [URL] = []
    private var openFilesBatchTask: Task<Void, Never>?
    private var isProcessing = false

    func submit(urls: [URL], source: RequestSource) {
        switch source {
        case .openFiles:
            bufferedOpenFileURLs.append(contentsOf: urls)
            scheduleOpenFilesBatchFlush()
            return
        case .commandLine:
            break
        }

        pendingRequests.append(StitchRequest(urls: urls, source: source))
        processNextIfNeeded()
    }

    private func scheduleOpenFilesBatchFlush() {
        openFilesBatchTask?.cancel()
        openFilesBatchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.openFilesBatchWindowNanoseconds ?? 0)
            } catch {
                return
            }

            self?.flushBufferedOpenFiles()
        }
    }

    private func flushBufferedOpenFiles() {
        guard !bufferedOpenFileURLs.isEmpty else {
            return
        }

        let urls = bufferedOpenFileURLs
        bufferedOpenFileURLs = []
        openFilesBatchTask = nil
        pendingRequests.append(StitchRequest(urls: urls, source: .openFiles))
        processNextIfNeeded()
    }

    private func processNextIfNeeded() {
        guard !isProcessing, !pendingRequests.isEmpty else {
            return
        }

        let request = pendingRequests.removeFirst()
        isProcessing = true

        Task {
            await handle(request: request)
            isProcessing = false

            if pendingRequests.isEmpty, bufferedOpenFileURLs.isEmpty, openFilesBatchTask == nil {
                NSApp.terminate(nil)
            } else {
                processNextIfNeeded()
            }
        }
    }

    private func handle(request: StitchRequest) async {
        do {
            let orderedURLs = try normalizedURLs(from: request)
            let stitchedImage = try await Task.detached(priority: .userInitiated) {
                try ImageStitcher().stitch(urls: orderedURLs)
            }.value

            if ProcessInfo.processInfo.environment["PHOTOS_STITCH_SKIP_IMPORT"] == "1" {
                let preservedURL = try FilePersistence.preserveForTesting(from: stitchedImage.url)
                print("PHOTOS_STITCH_OUTPUT=\(preservedURL.path)")
                if let creationDate = stitchedImage.preferredCreationDate {
                    print("PHOTOS_STITCH_CREATION_DATE=\(iso8601Formatter.string(from: creationDate))")
                }
                return
            }

            let destination = resolveDestination(for: orderedURLs)

            switch destination {
            case .photosLibrary:
                try await importToPhotos(stitchedImage: stitchedImage)
            case .fileSystem(let directory):
                try saveToFileSystem(stitchedImage: stitchedImage, directory: directory)
            }
        } catch let error as UserFacingError {
            alertPresenter.showError(error)
        } catch {
            alertPresenter.showError(UserFacingError(
                title: L10n.string("error.stitch_failed.title"),
                message: error.localizedDescription
            ))
        }
    }

    private func resolveDestination(for urls: [URL]) -> OutputDestination {
        let allFromPhotosLibrary = urls.allSatisfy { url in
            url.standardizedFileURL.path.contains(".photoslibrary/")
        }

        if allFromPhotosLibrary {
            return .photosLibrary
        }

        let firstNonLibraryDirectory = urls
            .first { !$0.standardizedFileURL.path.contains(".photoslibrary/") }
            .map { $0.deletingLastPathComponent() }

        return .fileSystem(directory: firstNonLibraryDirectory ?? urls[0].deletingLastPathComponent())
    }

    private func importToPhotos(stitchedImage: StitchedImage) async throws {
        do {
            try await PhotosImporter().importImage(
                at: stitchedImage.url,
                creationDate: stitchedImage.preferredCreationDate
            )
            try? FileManager.default.removeItem(at: stitchedImage.url)
        } catch let error as UserFacingError {
            let preservedURL = try? FilePersistence.preserveFailedOutput(from: stitchedImage.url)
            throw rewrittenImportError(error, preservedURL: preservedURL, format: stitchedImage.format)
        } catch {
            let preservedURL = try? FilePersistence.preserveFailedOutput(from: stitchedImage.url)
            let wrappedError = UserFacingError(
                title: L10n.string("error.import_failed.title"),
                message: error.localizedDescription
            )
            throw rewrittenImportError(wrappedError, preservedURL: preservedURL, format: stitchedImage.format)
        }
    }

    private func saveToFileSystem(stitchedImage: StitchedImage, directory: URL) throws {
        let savedURL: URL

        do {
            savedURL = try FilePersistence.saveToDirectory(directory, from: stitchedImage.url)
        } catch {
            let fallbackURL = try? FilePersistence.preserveFailedOutput(from: stitchedImage.url)
            let locationHint = fallbackURL.map { L10n.string("error.save_failed.fallback_hint", $0.path) } ?? ""
            throw UserFacingError(
                title: L10n.string("error.save_failed.title"),
                message: L10n.string("error.save_failed.message", directory.path) + locationHint
            )
        }

        revealInFinder(savedURL)
    }

    private func revealInFinder(_ url: URL) {
        let path = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Finder\" to reveal (POSIX file \"\(path)\" as alias)"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    private func normalizedURLs(from request: StitchRequest) throws -> [URL] {
        let orderedURLs = deduplicate(request.urls)
            .filter(\.isFileURL)
            .map { $0.standardizedFileURL }

        guard orderedURLs.count >= 2 else {
            throw insufficientInputError(for: request.source)
        }

        return orderedURLs
    }

    private func deduplicate(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        var result: [URL] = []

        for url in urls {
            let path = url.standardizedFileURL.path

            if seenPaths.insert(path).inserted {
                result.append(url)
            }
        }

        return result
    }

    private func insufficientInputError(for source: RequestSource) -> UserFacingError {
        switch source {
        case .openFiles:
            return UserFacingError(
                title: L10n.string("error.insufficient.title"),
                message: L10n.string("error.insufficient.open_files")
            )
        case .commandLine:
            return UserFacingError(
                title: L10n.string("error.insufficient.title"),
                message: L10n.string("error.insufficient.command_line")
            )
        }
    }

    private func rewrittenImportError(
        _ error: UserFacingError,
        preservedURL: URL?,
        format: UTType
    ) -> UserFacingError {
        guard let preservedURL else {
            return error
        }

        return UserFacingError(
            title: error.title,
            message: L10n.string(
                "error.import_rewritten.message",
                error.message,
                format.identifier,
                preservedURL.path
            )
        )
    }
}
