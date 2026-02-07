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
    
    // Helper to get URL with security access capability
    func getURL() -> URL? {
        var url: URL
        if let data = bookmarkData {
            var isStale = false
            do {
                url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    print("Bookmark is stale for \(path)")
                    // In a real app, we'd regenerate it
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
                return URL(fileURLWithPath: path) // Fallback
            }
        } else {
            url = URL(fileURLWithPath: path)
        }
        return url
    }
}

class CloudManager: ObservableObject {
    static let shared = CloudManager() // Singleton for easy access if needed, but we'll inject via VM
    
    @Published var destinations: [CloudDestination] = []
    @Published var activeDestinationId: UUID?
    
    private let destinationsKey = "savedCloudDestinations"
    private let activeDestKey = "activeCloudDestinationId"
    
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
            destinations = decoded
        }
        
        if let idString = UserDefaults.standard.string(forKey: activeDestKey),
           let id = UUID(uuidString: idString) {
            activeDestinationId = id
        }
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
        var bookmark: Data?
        do {
            bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Failed to create bookmark: \(error)")
        }
        
        let newDest = CloudDestination(name: name, path: url.path, bookmarkData: bookmark, provider: provider)
        destinations.append(newDest)
        
        if destinations.count == 1 {
            activeDestinationId = newDest.id
        }
        
        saveDestinations()
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
    
    // Safer Move Logic: Copy + Remove
    func moveFileToCloud(_ file: DesktopFile, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let dest = activeDestination else {
            completion(.failure(NSError(domain: "CloudManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active cloud destination"])))
            return
        }
        
        guard let destURL = dest.getURL() else {
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
        
        let targetURL = destURL.appendingPathComponent(file.name)
        let fileManager = FileManager.default
        
        do {
            // Check if exists
            if fileManager.fileExists(atPath: targetURL.path) {
                // Determine collision policy: overwrite or rename?
                // For now, let's error or append number. User typically wants move.
                // Let's try to overwrite for now or handle error.
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
            }
            
            // Try COPY then REMOVE
            try fileManager.copyItem(at: file.url, to: targetURL)
            
            // If copy succeeded, remove original
            // We use file.url for original. We assume we have access to it (since it's in the folder we are scanning).
            try fileManager.removeItem(at: file.url)
            
            completion(.success(()))
            
        } catch {
            print("Cloud Move Error: \(error)")
            completion(.failure(error))
        }
    }
}
