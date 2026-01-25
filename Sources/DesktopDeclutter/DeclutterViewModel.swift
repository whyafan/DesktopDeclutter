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
    
    // Filters
    @Published var selectedFileTypeFilter: FileType? = nil
    
    // Suggestions
    @Published var currentFileSuggestions: [FileSuggestion] = []
    @Published var showGroupReview = false
    @Published var groupReviewFiles: [DesktopFile] = []
    private var suggestionCache: [UUID: [FileSuggestion]] = [:]
    
    var filteredFiles: [DesktopFile] {
        if let filter = selectedFileTypeFilter {
            return files.filter { $0.fileType == filter }
        }
        return files
    }
    
    private var lastSuggestionFileId: UUID? = nil
    private var suggestionTask: Task<Void, Never>? = nil
    
    var currentFile: DesktopFile? {
        guard currentFileIndex < filteredFiles.count else { 
            // Clear suggestions when no file
            if !currentFileSuggestions.isEmpty {
                currentFileSuggestions = []
            }
            return nil 
        }
        let file = filteredFiles[currentFileIndex]
        
        // Only update suggestions when file actually changes
        if lastSuggestionFileId != file.id {
            lastSuggestionFileId = file.id
            
            // Cancel previous suggestion task
            suggestionTask?.cancel()
            
            // Start new suggestion detection
            updateSuggestionsAsync(for: file)
        }
        
        return file
    }
    
    private func updateSuggestionsAsync(for file: DesktopFile) {
        // Check cache first
        if let cached = suggestionCache[file.id] {
            currentFileSuggestions = cached
            return
        }
        
        // Show empty suggestions immediately (will update when ready)
        currentFileSuggestions = []
        
        // Cancel any existing task
        suggestionTask?.cancel()
        
        // Run detection on background thread with cancellation support
        suggestionTask = Task {
            // Limit files to compare against (only check first 100 files for performance)
            // This prevents slowdowns with large desktop collections
            let filesToCheck = Array(files.prefix(100))
            
            // Small delay to debounce rapid file changes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            let suggestions = await SuggestionDetector.shared.detectSuggestionsAsync(for: file, in: filesToCheck)
            
            guard !Task.isCancelled else { return }
            
            // Update on main thread
            await MainActor.run {
                // Only update if this file is still current
                if lastSuggestionFileId == file.id && suggestionCache[file.id] == nil {
                    currentFileSuggestions = suggestions
                    suggestionCache[file.id] = suggestions
                }
            }
        }
    }
    
    var isFinished: Bool {
        currentFileIndex >= filteredFiles.count
    }
    
    // Undo/Redo
    private struct Action: Equatable {
        let type: ActionType
        let file: DesktopFile
        let previousIndex: Int
        let fileOriginalIndex: Int? // Original position in files array
        
        enum ActionType: Equatable {
            case keep
            case bin
            case stack
        }
    }
    
    private var actionHistory: [Action] = []
    private var maxHistorySize = 50
    
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
            self.selectedFileTypeFilter = nil // Reset filter
            self.suggestionCache.removeAll() // Clear suggestion cache
            self.currentFileSuggestions = []
            self.lastSuggestionFileId = nil
            self.thumbnailGenerationInProgress.removeAll()
            
            // Trigger thumbnail generation for the first file only (lazy load others)
            generateThumbnails(for: 0)
        } catch {
            self.errorMessage = error.localizedDescription
            self.files = []
            self.totalFilesCount = 0
        }
    }
    
    func setFileTypeFilter(_ type: FileType?) {
        selectedFileTypeFilter = type
        currentFileIndex = 0 // Reset to start of filtered list
        generateThumbnails(for: 0)
    }
    
    private var thumbnailGenerationInProgress = Set<UUID>()
    
    func generateThumbnails(for index: Int) {
        // Preload thumbnails for current and next 2 files only (limit concurrent generation)
        let filesToProcess = filteredFiles
        let range = index..<min(index + 2, filesToProcess.count) // Reduced from 3 to 2
        
        for i in range {
            let file = filesToProcess[i]
            
            // Skip if already generating or already has thumbnail
            guard !thumbnailGenerationInProgress.contains(file.id),
                  let fileIndex = files.firstIndex(where: { $0.id == file.id }),
                  files[fileIndex].thumbnail == nil else {
                continue
            }
            
            // Mark as in progress
            thumbnailGenerationInProgress.insert(file.id)
            
            FileScanner.shared.generateThumbnail(for: file) { [weak self] image in
                guard let self = self else { return }
                
                // Update on main thread
                Task { @MainActor in
                    if fileIndex < self.files.count {
                        self.files[fileIndex].thumbnail = image
                    }
                    self.thumbnailGenerationInProgress.remove(file.id)
                }
            }
        }
    }
    
    // Note: currentFile and isFinished are now computed properties above
    
    func keepCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.keep, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
        keptCount += 1
        moveToNext()
    }
    
    func binCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.bin, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
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
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.stack, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
        stackedFiles.append(file)
        moveToNext()
    }
    
    private func recordAction(_ type: Action.ActionType, file: DesktopFile, originalIndex: Int?) {
        let action = Action(
            type: type,
            file: file,
            previousIndex: currentFileIndex,
            fileOriginalIndex: originalIndex
        )
        actionHistory.append(action)
        
        // Limit history size
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }
    
    func undoLastAction() -> Bool {
        guard let lastAction = actionHistory.popLast() else {
            return false
        }
        
        // Re-insert the file back into the files array
        if let originalIndex = lastAction.fileOriginalIndex, originalIndex <= files.count {
            // Insert at original position if possible
            files.insert(lastAction.file, at: min(originalIndex, files.count))
        } else {
            // If we don't have original index, insert at the previous position
            let insertIndex = min(lastAction.previousIndex, files.count)
            files.insert(lastAction.file, at: insertIndex)
        }
        
        // Undo the action and restore counters
        switch lastAction.type {
        case .keep:
            keptCount = max(0, keptCount - 1)
            
        case .bin:
            binnedCount = max(0, binnedCount - 1)
            reclaimedSpace = max(0, reclaimedSpace - lastAction.file.fileSize)
            
            // Remove from binned files if it was collected for review
            if !immediateBinning {
                binnedFiles.removeAll { $0.id == lastAction.file.id }
            }
            // Note: If immediate binning was used, file is already in trash
            // We can't restore it from trash, but we've added it back to the list
            // User would need to manually restore from trash if they want the actual file
            
        case .stack:
            stackedFiles.removeAll { $0.id == lastAction.file.id }
        }
        
        // Restore file index to point to the file we were looking at
        // Find the file in the filtered list
        let filtered = filteredFiles
        if let newIndex = filtered.firstIndex(where: { $0.id == lastAction.file.id }) {
            withAnimation {
                currentFileIndex = newIndex
            }
        } else {
            // If file doesn't match current filter, restore to previous index
            withAnimation {
                currentFileIndex = min(lastAction.previousIndex, filtered.count)
            }
        }
        
        // Regenerate thumbnails for current position
        generateThumbnails(for: currentFileIndex)
        
        return true
    }
    
    var canUndo: Bool {
        !actionHistory.isEmpty
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
            // Don't increment if we're already at the end
            if currentFileIndex < filteredFiles.count {
                currentFileIndex += 1
            }
            // If we've gone past the end, clamp to the end
            if currentFileIndex >= filteredFiles.count {
                currentFileIndex = filteredFiles.count
            }
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
    
    // MARK: - Group Review
    
    func startGroupReview(for suggestion: FileSuggestion) {
        let groupFiles: [DesktopFile]
        
        switch suggestion.type {
        case .duplicate(_, let files),
             .similarNames(_, _, let files),
             .sameSession(_, let files):
            groupFiles = files
        default:
            return
        }
        
        groupReviewFiles = groupFiles
        showGroupReview = true
    }
    
    func binGroupFiles(_ filesToBin: [DesktopFile]) {
        for file in filesToBin {
            if files.contains(where: { $0.id == file.id }) {
                // Remove from files and bin
                files.removeAll { $0.id == file.id }
                
                if immediateBinning {
                    do {
                        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                        binnedCount += 1
                        reclaimedSpace += file.fileSize
                    } catch {
                        binnedCount += 1
                        reclaimedSpace += file.fileSize
                    }
                } else {
                    binnedFiles.append(file)
                    binnedCount += 1
                    reclaimedSpace += file.fileSize
                }
            }
        }
        
        // Clear suggestion cache for removed files
        for file in filesToBin {
            suggestionCache.removeValue(forKey: file.id)
        }
        
        showGroupReview = false
        groupReviewFiles = []
    }
    
    func keepGroupFiles(_ filesToKeep: [DesktopFile]) {
        for file in filesToKeep {
            files.removeAll { $0.id == file.id }
            keptCount += 1
            suggestionCache.removeValue(forKey: file.id)
        }
        
        showGroupReview = false
        groupReviewFiles = []
    }
}
