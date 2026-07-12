import UIKit

/// Stores user images (mosaic photos, previews, Brick Bar references) as
/// JPEGs in the app's Documents directory. Uploaded photos stay on-device
/// and private (§13.7).
enum ImageStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("BrickStudioImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.82) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String) {
        guard !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    static func saveVideo(from sourceURL: URL) -> String? {
        let filename = UUID().uuidString + "." + (sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        let destination = directory.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return filename
        } catch {
            return nil
        }
    }

    static func videoURL(_ filename: String) -> URL? {
        guard !filename.isEmpty else { return nil }
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
