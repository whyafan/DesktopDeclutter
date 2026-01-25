import Foundation
import AppKit
import QuickLookThumbnailing

struct DesktopFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let fileSize: Int64
    var thumbnail: NSImage?
    
    // Default fallback icon
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    static func == (lhs: DesktopFile, rhs: DesktopFile) -> Bool {
        lhs.id == rhs.id
    }
}

class FileScanner {
    static let shared = FileScanner()
    
    private let fileManager = FileManager.default
    
    func scanDesktop() throws -> [DesktopFile] {
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "DesktopDeclutter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find Desktop directory."])
        }
        
         if !fileManager.isReadableFile(atPath: desktopURL.path) {
             throw NSError(domain: "DesktopDeclutter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Access to Desktop denied. Please grant permission in System Settings."])
        }
        
        let fileURLs = try fileManager.contentsOfDirectory(at: desktopURL, includingPropertiesForKeys: [.fileSizeKey])
        
        var files: [DesktopFile] = []
        
        for url in fileURLs {
            let filename = url.lastPathComponent
            if !filename.hasPrefix(".") && !filename.hasPrefix("$") {
                
                // Get File Size
                let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
                let size = Int64(resources?.fileSize ?? 0)
                
                files.append(DesktopFile(id: UUID(), url: url, name: filename, fileSize: size, thumbnail: nil))
            }
        }
        return files
    }
    
    // Async thumbnail generation
    func generateThumbnail(for file: DesktopFile, completion: @escaping (NSImage?) -> Void) {
        let size = CGSize(width: 300, height: 300)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        let request = QLThumbnailGenerator.Request(fileAt: file.url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    completion(thumbnail.nsImage)
                }
            } else {
                // Fallback or error, return nil so UI uses icon
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
