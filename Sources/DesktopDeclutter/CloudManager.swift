import Foundation
import SwiftUI

enum CloudProvider: String, CaseIterable, Identifiable, Codable {
    case iCloud = "iCloud Drive"
    case googleDrive = "Google Drive"
    case custom = "Custom"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .iCloud: return "icloud.fill"
        case .googleDrive: return "externaldrive.fill"
        case .custom: return "folder.fill"
        }
    }
}

struct CloudDestination: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var path: String
    var bookmarkData: Data?
    var provider: CloudProvider
}

class CloudManager: ObservableObject {
    static let shared = CloudManager() // Singleton for easy access if needed, but we'll inject via VM
    
    @Published var destinations: [CloudDestination] = []
    @Published var activeDestinationId: UUID?
    
    private let destinationsKey = "savedCloudDestinations"
    private let activeDestKey = "activeCloudDestinationId"
    private let appFolderName = "DesktopDeclutter"
    
    init() {
        loadDestinations()
    }
    
    var activeDestination: CloudDestination? {
        guard let id = activeDestinationId else { return destinations.first }
        return destinations.first(where: { $0.id == id })
    }
    
    func loadDestinations() {
        if let data = UserDefaults.standard.data(forKey: destinationsKey),
           let decoded = try? JSONDecoder().decode([CloudDestination].self, from: data) {
            destinations = decoded.map { dest in
                guard dest.provider == .googleDrive else { return dest }
                if URL(fileURLWithPath: dest.path).lastPathComponent.hasPrefix("GoogleDrive-") {
                    let myDrive = URL(fileURLWithPath: dest.path).appendingPathComponent("My Drive", isDirectory: true)
                    if FileManager.default.fileExists(atPath: myDrive.path) {
                        var updated = dest
                        updated.name = myDrive.lastPathComponent
                        updated.path = myDrive.path
                        updated.bookmarkData = createBookmark(for: myDrive)
                        return updated
                    }
                }
                return dest
            }
        }
        
        if let idString = UserDefaults.standard.string(forKey: activeDestKey),
           let id = UUID(uuidString: idString) {
            activeDestinationId = id
        }

        saveDestinations()
    }
    
    func saveDestinations() {
        if let encoded = try? JSONEncoder().encode(destinations) {
            UserDefaults.standard.set(encoded, forKey: destinationsKey)
        }
        if let id = activeDestinationId {
            UserDefaults.standard.set(id.uuidString, forKey: activeDestKey)
        }
    }
    
    func addDestination(name: String, url: URL, provider: CloudProvider) {
        // Create security scoped bookmark
        let bookmark = createBookmark(for: url)
        
        let newDest = CloudDestination(name: name, path: url.path, bookmarkData: bookmark, provider: provider)
        destinations.append(newDest)
        
        if destinations.count == 1 {
            activeDestinationId = newDest.id
        }
        
        saveDestinations()
    }

    func isValidCloudDirectory(_ url: URL) -> CloudProvider? {
        let path = url.path
        let lowercased = path.lowercased()
        if lowercased.contains("/library/mobile documents/") {
            return .iCloud
        }
        if lowercased.contains("/library/cloudstorage/") {
            if lowercased.contains("googledrive") || lowercased.contains("google drive") {
                return .googleDrive
            }
            return .custom
        }
        return nil
    }

    func canonicalCloudURL(for url: URL, provider: CloudProvider) -> URL? {
        switch provider {
        case .googleDrive:
            let path = url.path
            let lowercased = path.lowercased()
            if lowercased.hasSuffix("/library/cloudstorage") {
                return url
            }
            if lowercased.contains("/library/cloudstorage/") {
                // If user selected the account root, force My Drive
                if url.lastPathComponent.hasPrefix("GoogleDrive-") {
                    let myDrive = url.appendingPathComponent("My Drive", isDirectory: true)
                    return myDrive
                }
                return url
            }
            return url
        default:
            return url
        }
    }

    func destinationDisplayName(_ destination: CloudDestination) -> String {
        switch destination.provider {
        case .googleDrive:
            let pathComponents = URL(fileURLWithPath: destination.path).pathComponents
            if let accountComponent = pathComponents.first(where: { $0.hasPrefix("GoogleDrive-") }) {
                let account = accountComponent.replacingOccurrences(of: "GoogleDrive-", with: "")
                return "\(destination.name) — \(account)"
            }
            return destination.name
        case .iCloud:
            return "iCloud Drive"
        case .custom:
            return destination.name
        }
    }

    func findDestination(matching url: URL) -> CloudDestination? {
        let path = url.standardizedFileURL.path
        return destinations.first(where: { dest in
            let destPath = URL(fileURLWithPath: dest.path).standardizedFileURL.path
            return path == destPath || path.hasPrefix(destPath + "/")
        })
    }

    func appRootURL(in destinationURL: URL) throws -> URL {
        let appFolderURL = destinationURL.appendingPathComponent(appFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        return appFolderURL
    }

    func validateDestinationWritable(_ url: URL) -> Result<Void, Error> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try appRootURL(in: url)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func removeDestination(id: UUID) {
        destinations.removeAll { $0.id == id }
        if activeDestinationId == id {
            activeDestinationId = destinations.first?.id
        }
        saveDestinations()
    }
    
    func setActive(_ id: UUID) {
        activeDestinationId = id
        saveDestinations()
    }
    
    private func uniqueURL(for url: URL, fileManager: FileManager) -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }

        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let parent = url.deletingLastPathComponent()
        var counter = 2

        while true {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            let candidate = parent.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    private func targetFolderURL(destinationURL: URL, sourceFolderName: String?) throws -> URL {
        let appRoot = try appRootURL(in: destinationURL)
        let safeSourceName = (sourceFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? sourceFolderName!
            : "Unsorted"
        let targetFolder = appRoot.appendingPathComponent(safeSourceName, isDirectory: true)
        try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        return targetFolder
    }

    private func createBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Failed to create bookmark: \(error)")
            return nil
        }
    }

    func resolvedURL(for destination: CloudDestination) -> URL? {
        guard let index = destinations.firstIndex(where: { $0.id == destination.id }) else {
            return URL(fileURLWithPath: destination.path)
        }

        var updatedDestination = destinations[index]
        if let data = updatedDestination.bookmarkData {
            var isStale = false
            do {
                let resolved = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale, let refreshed = createBookmark(for: resolved) {
                    updatedDestination.bookmarkData = refreshed
                    destinations[index] = updatedDestination
                    saveDestinations()
                }
                return resolved
            } catch {
                print("Failed to resolve bookmark: \(error)")
                updatedDestination.bookmarkData = nil
                let fallbackURL = URL(fileURLWithPath: updatedDestination.path)
                if let refreshed = createBookmark(for: fallbackURL) {
                    updatedDestination.bookmarkData = refreshed
                }
                destinations[index] = updatedDestination
                saveDestinations()
            }
        }

        return URL(fileURLWithPath: updatedDestination.path)
    }

    func resolvedURL(for destinationId: UUID?) -> URL? {
        guard let destinationId else { return nil }
        guard let destination = destinations.first(where: { $0.id == destinationId }) else { return nil }
        return resolvedURL(for: destination)
    }

    // Safer Move Logic: Copy + Remove
    func moveFileToCloud(_ file: DesktopFile, sourceFolderName: String?, destination: CloudDestination? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        let resolvedDestination = destination ?? activeDestination
        guard let dest = resolvedDestination else {
            completion(.failure(NSError(domain: "CloudManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active cloud destination"])))
            return
        }

        guard let destURL = resolvedURL(for: dest) else {
            completion(.failure(NSError(domain: "CloudManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid destination URL"])))
            return
        }

        // Start accessing security scoped resource
        let accessing = destURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                destURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default

        do {
            let targetFolder = try targetFolderURL(destinationURL: destURL, sourceFolderName: sourceFolderName)
            let initialTargetURL = targetFolder.appendingPathComponent(file.name)
            let targetURL = uniqueURL(for: initialTargetURL, fileManager: fileManager)

            // Try COPY then REMOVE
            try fileManager.copyItem(at: file.url, to: targetURL)
            try fileManager.removeItem(at: file.url)

            completion(.success(targetURL))
        } catch {
            print("Cloud Move Error: \(error)")
            completion(.failure(error))
        }
    }
}
