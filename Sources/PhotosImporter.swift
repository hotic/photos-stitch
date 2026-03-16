import Foundation
import Photos

struct PhotosImporter {
    func importImage(at url: URL, creationDate: Date?, sourceURLs: [URL] = []) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        switch status {
        case .authorized, .limited:
            break
        case .denied, .restricted:
            throw UserFacingError(
                title: L10n.string("error.photos_denied.title"),
                message: L10n.string("error.photos_denied.message")
            )
        case .notDetermined:
            throw UserFacingError(
                title: L10n.string("error.photos_undetermined.title"),
                message: L10n.string("error.photos_undetermined.message")
            )
        @unknown default:
            throw UserFacingError(
                title: L10n.string("error.photos_unknown.title"),
                message: L10n.string("error.photos_unknown.message")
            )
        }

        let album: PHAssetCollection? = (status == .authorized)
            ? findCommonUserAlbum(for: sourceURLs)
            : nil

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                request?.creationDate = creationDate

                if let album, let placeholder = request?.placeholderForCreatedAsset {
                    let albumRequest = PHAssetCollectionChangeRequest(for: album)
                    albumRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            }
        } catch {
            throw UserFacingError(
                title: L10n.string("error.import_failed.title"),
                message: error.localizedDescription
            )
        }
    }

    // Find the user-created album that contains all source assets.
    private func findCommonUserAlbum(for urls: [URL]) -> PHAssetCollection? {
        let assets = resolveAssets(from: urls)
        guard let firstAsset = assets.first else { return nil }

        let collections = PHAssetCollection.fetchAssetCollectionsContaining(
            firstAsset,
            with: .album,
            options: nil
        )

        var candidates: [PHAssetCollection] = []
        collections.enumerateObjects { collection, _, _ in
            candidates.append(collection)
        }

        guard !candidates.isEmpty else { return nil }
        guard assets.count > 1 else { return candidates.first }

        let inputIds = Set(assets.map(\.localIdentifier))

        for album in candidates {
            let albumAssets = PHAsset.fetchAssets(in: album, options: nil)
            var albumIds = Set<String>()
            albumAssets.enumerateObjects { asset, _, _ in
                albumIds.insert(asset.localIdentifier)
            }
            if inputIds.isSubset(of: albumIds) {
                return album
            }
        }

        return nil
    }

    private func resolveAssets(from urls: [URL]) -> [PHAsset] {
        let identifiers = urls.compactMap { extractLocalIdentifier(from: $0) }
        guard !identifiers.isEmpty else { return [] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // Extract asset localIdentifier from Photos library internal paths.
    // "Edit With" path: .../ExternalEditSessions/UUID/filename
    // Originals path:   .../originals/X/UUID.ext
    private func extractLocalIdentifier(from url: URL) -> String? {
        let components = url.pathComponents
        if let idx = components.firstIndex(of: "ExternalEditSessions"),
           idx + 1 < components.count {
            let uuid = components[idx + 1]
            if UUID(uuidString: uuid) != nil {
                return "\(uuid)/L0/001"
            }
        }

        let name = url.deletingPathExtension().lastPathComponent
        if UUID(uuidString: name) != nil {
            return "\(name)/L0/001"
        }

        return nil
    }
}
