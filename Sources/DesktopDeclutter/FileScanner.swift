import AppKit
import Foundation
import QuickLookThumbnailing

class FileScanner {
    static let shared = FileScanner()

    private var folderURL: URL
    private let fileManager = FileManager.default

    private init() {
        if let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            self.folderURL = desktopURL
        } else {
            self.folderURL = fileManager.homeDirectoryForCurrentUser
        }
    }

    func useCustomURL(_ url: URL) {
        folderURL = url
    }

    func scanCurrentFolder() throws -> [DesktopFile] {
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .nameKey
        ]

        let urls = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        let files: [DesktopFile] = urls.compactMap { url in
            do {
                let values = try url.resourceValues(forKeys: resourceKeys)
                let isDirectory = values.isDirectory ?? false
                let size = Int64(values.fileSize ?? 0)
                let name = values.name ?? url.lastPathComponent
                let fileType = FileType.classify(url: url, isDirectory: isDirectory)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return DesktopFile(url: url, name: name, fileSize: size, fileType: fileType, icon: icon, thumbnail: nil)
            } catch {
                return nil
            }
        }

        // Sort: folders first, then by name (case-insensitive)
        return files.sorted {
            if $0.fileType == .folder && $1.fileType != .folder { return true }
            if $0.fileType != .folder && $1.fileType == .folder { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func generateThumbnail(for file: DesktopFile, completion: @escaping (NSImage?) -> Void) {
        if file.fileType == .folder {
            print("Thumbnail: skipping folder \(file.name)")
            completion(nil)
            return
        }
        let size = CGSize(width: 512, height: 512)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(fileAt: file.url, size: size, scale: scale, representationTypes: .all)

        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in
            if let error {
                print("Thumbnail error for \(file.name): \(error)")
            }
            if let image = thumbnail?.nsImage {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
}
