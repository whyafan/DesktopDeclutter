import AppKit
import Foundation

struct DesktopFile: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let fileSize: Int64
    let fileType: FileType
    let icon: NSImage
    var thumbnail: NSImage?

    init(id: UUID = UUID(), url: URL, name: String, fileSize: Int64, fileType: FileType, icon: NSImage, thumbnail: NSImage? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.fileSize = fileSize
        self.fileType = fileType
        self.icon = icon
        self.thumbnail = thumbnail
    }
    var decision: FileDecision? // nil = unprocessed

    init(id: UUID = UUID(), url: URL, name: String, fileSize: Int64, fileType: FileType, icon: NSImage, thumbnail: NSImage? = nil, decision: FileDecision? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.fileSize = fileSize
        self.fileType = fileType
        self.icon = icon
        self.thumbnail = thumbnail
        self.decision = decision
    }
}


enum FileDecision: String, Codable {
    case kept
    case binned
    case stacked
    case cloud
}

enum FileType: String, CaseIterable, Hashable {
    case image
    case video
    case audio
    case document
    case archive
    case app
    case folder
    case other

    var displayName: String {
        switch self {
        case .image: return "Images"
        case .video: return "Videos"
        case .audio: return "Audio"
        case .document: return "Documents"
        case .archive: return "Archives"
        case .app: return "Apps"
        case .folder: return "Folders"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .app: return "app"
        case .folder: return "folder"
        case .other: return "doc"
        }
    }

    static func classify(url: URL, isDirectory: Bool) -> FileType {
        if isDirectory { return .folder }
        if url.pathExtension.lowercased() == "app" { return .app }

        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "webp"].contains(ext) {
            return .image
        }
        if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext) {
            return .video
        }
        if ["mp3", "wav", "aiff", "m4a", "flac", "aac"].contains(ext) {
            return .audio
        }
        if ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "txt", "md", "pages", "numbers", "key"].contains(ext) {
            return .document
        }
        if ["zip", "rar", "7z", "tar", "gz", "bz2"].contains(ext) {
            return .archive
        }
        return .other
    }
}
