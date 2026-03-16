import Foundation
import Photos

struct PhotosImporter {
    func importImage(at url: URL, creationDate: Date?) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

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

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                request?.creationDate = creationDate
            }
        } catch {
            throw UserFacingError(
                title: L10n.string("error.import_failed.title"),
                message: error.localizedDescription
            )
        }
    }
}
