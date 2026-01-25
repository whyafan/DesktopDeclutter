import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var files: [DesktopFile] = []
    @Published var currentFileIndex: Int = 0
    @Published var binnedFiles: [DesktopFile] = []
    @Published var errorMessage: String? = nil
    
    @Published var reclaimedSpace: Int64 = 0
    
    // Stats
    @Published var keptCount: Int = 0
    @Published var binnedCount: Int = 0
    @Published var totalFilesCount: Int = 0
    
    // Modes
    @Published var immediateBinning: Bool = true
    
    // Stacked files (for later review)
    @Published var stackedFiles: [DesktopFile] = []
    
    // Preview
    @Published var previewUrl: URL? = nil
    
    init() {
        loadFiles()
    }
    
    func loadFiles() {
        self.errorMessage = nil
        do {
            let loadedFiles = try FileScanner.shared.scanDesktop()
            self.files = loadedFiles
            self.currentFileIndex = 0
            self.binnedFiles = []
            self.stackedFiles = []
            self.reclaimedSpace = 0
            self.keptCount = 0
            self.binnedCount = 0
            self.totalFilesCount = loadedFiles.count
            
            // Trigger thumbnail generation for the first few files
            generateThumbnails(for: 0)
        } catch {
            self.errorMessage = error.localizedDescription
            self.files = []
            self.totalFilesCount = 0
        }
    }
    
    func generateThumbnails(for index: Int) {
        // Preload thumbnails for current and next few files
        let range = index..<min(index + 3, files.count)
        for i in range {
            if files[i].thumbnail == nil {
                FileScanner.shared.generateThumbnail(for: files[i]) { [weak self] image in
                    self?.files[i].thumbnail = image
                }
            }
        }
    }
    
    var currentFile: DesktopFile? {
        guard currentFileIndex < files.count else { return nil }
        return files[currentFileIndex]
    }
    
    var isFinished: Bool {
        currentFileIndex >= files.count
    }
    
    func keepCurrentFile() {
        keptCount += 1
        moveToNext()
    }
    
    func binCurrentFile() {
        guard let file = currentFile else { return }
        
        if immediateBinning {
            // Immediately move to trash
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                binnedCount += 1
                reclaimedSpace += file.fileSize
                print("Immediately moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
                // Still count it as binned even if trash failed
                binnedCount += 1
                reclaimedSpace += file.fileSize
            }
        } else {
            // Collect for later review
            binnedFiles.append(file)
            binnedCount += 1
            reclaimedSpace += file.fileSize
        }
        
        moveToNext()
    }
    
    func stackCurrentFile() {
        guard let file = currentFile else { return }
        stackedFiles.append(file)
        moveToNext()
    }
    
    func removeFromStack(_ file: DesktopFile) {
        stackedFiles.removeAll { $0.id == file.id }
    }
    
    func emptyStack() {
        for file in stackedFiles {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                print("Moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
            }
        }
        stackedFiles.removeAll()
        loadFiles()
    }
    
    private func moveToNext() {
        withAnimation {
            currentFileIndex += 1
        }
        // Preload more as we move
        generateThumbnails(for: currentFileIndex)
    }
    
    func emptyBin() {
        for file in binnedFiles {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                print("Moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
            }
        }
        binnedFiles.removeAll()
        reclaimedSpace = 0 // Reset or keep? Usually reset as they are now gone.
        loadFiles()
    }
    
    var formattedReclaimedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: reclaimedSpace)
    }
}
