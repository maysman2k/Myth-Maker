import Foundation
import UIKit

/// Saves event photos to Application Support and loads downsampled
/// thumbnails. Stands in for Firebase Storage; the metadata model
/// (`EventPhoto.fileName`) maps straight onto a remote storage path later.
final class ImageStore: @unchecked Sendable {

    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PlanrPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Re-encodes as JPEG (client-side compression) and writes to disk.
    func saveJPEG(_ data: Data, id: String) throws -> String {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.uploadFailed
        }
        let fileName = "\(id).jpg"
        try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    func loadImage(named fileName: String, maxDimension: CGFloat = 1200) async -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return nil
        }
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return await image.byPreparingThumbnail(ofSize: size) ?? image
    }

    func deleteImage(named fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
