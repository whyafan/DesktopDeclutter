import AppKit
import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var files: [DesktopFile] = []
    @Published var currentFileIndex: Int = 0
    @Published var binnedFiles: [DesktopFile] = []
    @Published var errorMessage: String? = nil
    @Published var selectedFolderURL: URL? = nil
    @Published var breadcrumbText: String = ""
    
    @Published var reclaimedSpace: Int64 = 0
    
    // Stats
    @Published var keptCount: Int = 0
    @Published var binnedCount: Int = 0
    @Published var totalFilesCount: Int = 0
    
    // Modes
    @Published var immediateBinning: Bool = true
    @Published var isGridMode: Bool = false
    
    // Stacked files (for later review)
    @Published var stackedFiles: [DesktopFile] = []
    
    // Shake Animation State
    @Published var shakingFileId: UUID? = nil
    @Published var viewedFileIds: Set<UUID> = [] // Track files that have been viewed
    private var shakeTask: Task<Void, Never>? = nil
    
    // Preview
    @Published var previewUrl: URL? = nil

    // Move progress
    @Published var movingItemIds: Set<UUID> = []
    
    // Filters
    @Published var selectedFileTypeFilter: FileType? = nil
    
    // Cloud
    // Cloud Manager
    private let cloudManager = CloudManager.shared
    
    // File System
    private let fileManager = FileManager.default
    
    // Suggestions
    @Published var currentFileSuggestions: [FileSuggestion] = []
    @Published var showGroupReview = false
    @Published var groupReviewFiles: [DesktopFile] = []
    @Published var groupReviewSuggestion: FileSuggestion? = nil
    private var suggestionCache: [UUID: [FileSuggestion]] = [:]
    
    var filteredFiles: [DesktopFile] {
        if let filter = selectedFileTypeFilter {
            return files.filter { $0.fileType == filter }
        }
        return files
    }

    var movingCount: Int {
        movingItemIds.count
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
        
        // Mark as viewed
        if !viewedFileIds.contains(file.id) {
            viewedFileIds.insert(file.id)
        }
        
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
    

    
    /// Prevent duplicate folder-picker presentation.
    private var isPresentingFolderPicker = false
    /// Ensure we only prompt once per app launch.
    private var hasPromptedForFolder = false
    
    private struct FolderContext {
        let url: URL
        let files: [DesktopFile]
        let currentFileIndex: Int
        let selectedFileTypeFilter: FileType?
        let totalFilesCount: Int
        let suggestionCache: [UUID: [FileSuggestion]]
        let lastSuggestionFileId: UUID?
        let currentFileSuggestions: [FileSuggestion]
        let thumbnailGenerationInProgress: Set<UUID>
    }
    
    private var folderStack: [FolderContext] = []

    init() {}

    /// Prompt the user to choose a folder to scan on launch.
    /// Uses NSOpenPanel.begin for non-blocking presentation.
    @MainActor
    func promptForFolderIfNeeded() {
        guard !hasPromptedForFolder else { return }
        hasPromptedForFolder = true

        if selectedFolderURL == nil {
            promptForFolderAndLoad()
        }
    }

    @MainActor
    func promptForFolderAndLoad() {
        guard !isPresentingFolderPicker else { return }
        isPresentingFolderPicker = true

        // Bring app to front so the panel is visible.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose a folder to declutter"
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.makeKeyAndOrderFront(nil)

        panel.begin { [weak self] response in
            guard let self else { return }
            Task { @MainActor in
                self.isPresentingFolderPicker = false

                if response == .OK, let url = panel.url {
                    self.selectedFolderURL = url
                    FileScanner.shared.useCustomURL(url)
                    self.loadFiles()
                }
            }
        }
    }
    
    func loadFiles() {
        self.errorMessage = nil
        do {
            let loadedFiles = try FileScanner.shared.scanCurrentFolder()
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
            self.totalFilesCount = loadedFiles.count
            updateBreadcrumbs()
            
            // Trigger thumbnail generation for the first file only (lazy load others)
            generateThumbnails(for: 0)
            
            // If empty, enforce choosing another folder (top-level only).
            if loadedFiles.isEmpty {
                if folderStack.isEmpty {
                    promptForFolderAndLoad()
                } else {
                    returnToParentFolder()
                }
            }
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
        
        // Find the actual file in the main 'files' array and update its decision
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].decision = .kept
            keptCount += 1
            recordAction(.keep, file: file, decision: .kept)
            moveToNext()
        }
    }
    
    func binCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find the actual file in the main 'files' array and update its decision
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].decision = .binned
            binnedCount += 1
            reclaimedSpace += file.fileSize
            
            if immediateBinning {
                // Immediately move to trash
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                    print("Immediately moved to trash: \(file.name)")
                } catch {
                    print("Failed to trash file \(file.name): \(error)")
                    // Still count it as binned even if trash failed
                }
            } else {
                // Collect for later review
                binnedFiles.append(file)
            }
            recordAction(.bin, file: file, decision: .binned)
            moveToNext()
        }
    }
    
    func stackCurrentFile() {
        guard let file = currentFile else { return }
        
        // Mark as stacked
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].decision = .stacked
        }
        
        stackedFiles.append(file)
        recordAction(.stack, file: file)
        moveToNext()
    }
    
    func moveToCloud(_ file: DesktopFile, destination: CloudDestination? = nil) {
        let sourceFolderName = selectedFolderURL?.lastPathComponent
        cloudManager.moveFileToCloud(file, sourceFolderName: sourceFolderName, destination: destination) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let movedToURL):
                    // Update state
                    if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                        self.files[index].decision = .cloud
                    }
                    self.recordAction(.cloud, file: file, decision: .cloud, movedToURL: movedToURL, destinationId: destination?.id ?? self.cloudManager.activeDestinationId)
                    self.moveToNext()
                    
                case .failure(let error):
                    print("Failed to move to cloud: \(error)")
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain && nsError.code == 513 {
                        self.errorMessage = "Permission denied. Please re-add the cloud destination and choose a writable folder (e.g., Google Drive → My Drive)."
                    } else {
                        self.errorMessage = "Failed to move to Cloud: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func moveGroupToCloud(_ filesToMove: [DesktopFile], destination: CloudDestination? = nil) {
        // Naive serial implementation for now, or parallel?
        // Let's do parallel but just trigger all.
        for file in filesToMove {
            let sourceFolderName = selectedFolderURL?.lastPathComponent
            cloudManager.moveFileToCloud(file, sourceFolderName: sourceFolderName, destination: destination) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let movedToURL):
                        if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                            self.files[index].decision = .cloud
                        }
                        self.recordAction(.cloud, file: file, decision: .cloud, movedToURL: movedToURL, destinationId: destination?.id ?? self.cloudManager.activeDestinationId)
                    case .failure(let error):
                        print("Failed to move \(file.name): \(error)")
                        let nsError = error as NSError
                        if nsError.domain == NSCocoaErrorDomain && nsError.code == 513 {
                            self.errorMessage = "Permission denied. Please re-add the cloud destination and choose a writable folder (e.g., Google Drive → My Drive)."
                        }
                    }
                }
            }
        }
        
        // If current file was in the group, move next
        // (This might happen before moves verify, but UI responsiveness is key)
        if let current = currentFile, filesToMove.contains(where: { $0.id == current.id }) {
            moveToNext()
        }
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

    func moveToFolder(_ file: DesktopFile, destinationURL: URL) {
        Task { @MainActor in
            movingItemIds.insert(file.id)
        }
        Task.detached { [file, destinationURL] in
            let fileManager = FileManager.default
            func uniqueURL(for url: URL) -> URL {
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

            let targetURL = uniqueURL(for: destinationURL.appendingPathComponent(file.name))
            let accessing = destinationURL.startAccessingSecurityScopedResource()
            defer { if accessing { destinationURL.stopAccessingSecurityScopedResource() } }

            do {
                do {
                    try fileManager.moveItem(at: file.url, to: targetURL)
                } catch {
                    if !fileManager.fileExists(atPath: file.url.path),
                       fileManager.fileExists(atPath: targetURL.path) {
                        // Move likely already completed in background; treat as success.
                    } else {
                        try fileManager.copyItem(at: file.url, to: targetURL)
                        try fileManager.removeItem(at: file.url)
                    }
                }

                await MainActor.run {
                    if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                        self.files[index].decision = .moved
                    }
                    self.recordAction(.move, file: file, decision: .moved, movedToURL: targetURL)
                    self.movingItemIds.remove(file.id)
                    self.moveToNext()
                }
            } catch {
                print("Move Error: \(error)")
                await MainActor.run {
                    self.movingItemIds.remove(file.id)
                    self.errorMessage = "Failed to move: \(error.localizedDescription)"
                }
            }
        }
    }

    func moveGroupToFolder(_ filesToMove: [DesktopFile], destinationURL: URL) {
        Task { @MainActor in
            for file in filesToMove {
                movingItemIds.insert(file.id)
            }
        }
        Task.detached { [filesToMove, destinationURL] in
            let fileManager = FileManager.default
            func uniqueURL(for url: URL) -> URL {
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

            let accessing = destinationURL.startAccessingSecurityScopedResource()
            defer { if accessing { destinationURL.stopAccessingSecurityScopedResource() } }

            for file in filesToMove {
                let targetURL = uniqueURL(for: destinationURL.appendingPathComponent(file.name))
                do {
                    do {
                        try fileManager.moveItem(at: file.url, to: targetURL)
                    } catch {
                        if !fileManager.fileExists(atPath: file.url.path),
                           fileManager.fileExists(atPath: targetURL.path) {
                            // Move likely already completed in background; treat as success.
                        } else {
                            try fileManager.copyItem(at: file.url, to: targetURL)
                            try fileManager.removeItem(at: file.url)
                        }
                    }

                    await MainActor.run {
                        if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                            self.files[index].decision = .moved
                        }
                        self.recordAction(.move, file: file, decision: .moved, movedToURL: targetURL)
                        self.movingItemIds.remove(file.id)
                    }
                } catch {
                    print("Move Error for \(file.name): \(error)")
                    _ = await MainActor.run {
                        self.movingItemIds.remove(file.id)
                    }
                }
            }

            await MainActor.run {
                if let current = self.currentFile, filesToMove.contains(where: { $0.id == current.id }) {
                    self.moveToNext()
                }
            }
        }
    }

    @MainActor
    func promptForMoveDestination(files: [DesktopFile]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move Here"
        panel.message = "Choose a folder to move the selected items into."
        panel.level = .floating
        panel.isFloatingPanel = true

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        panel.begin { [weak self] response in
            guard let self else { return }
            if response == .OK, let url = panel.url {
                if let provider = self.cloudManager.isValidCloudDirectory(url) {
                    let canonicalURL = self.cloudManager.canonicalCloudURL(for: url, provider: provider) ?? url
                    let alert = NSAlert()
                    alert.messageText = "Destination is a cloud folder"
                    alert.informativeText = "The destination you chose is a cloud directory. Cloud moves are safer and keep your files organized under DesktopDeclutter."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Use Cloud")
                    alert.addButton(withTitle: "Move Anyway")
                    alert.addButton(withTitle: "Cancel")

                    let choice = alert.runModal()
                    if choice == .alertFirstButtonReturn {
                        let dest = self.cloudManager.findDestination(matching: canonicalURL)
                            ?? CloudDestination(name: canonicalURL.lastPathComponent, path: canonicalURL.path, bookmarkData: nil, provider: provider)

                        if self.cloudManager.findDestination(matching: canonicalURL) == nil {
                            self.cloudManager.addDestination(name: dest.name, url: canonicalURL, provider: provider)
                        }

                        if files.count == 1, let file = files.first {
                            self.moveToCloud(file, destination: self.cloudManager.findDestination(matching: canonicalURL))
                        } else {
                            let destination = self.cloudManager.findDestination(matching: canonicalURL)
                            self.moveGroupToCloud(files, destination: destination)
                        }
                        return
                    } else if choice == .alertThirdButtonReturn {
                        return
                    }
                }

                if files.count == 1, let file = files.first {
                    self.moveToFolder(file, destinationURL: url)
                } else {
                    self.moveGroupToFolder(files, destinationURL: url)
                }
            }
        }
    }
    
    // MARK: - History
    
    // MARK: - History
    
    struct Action: Equatable, Identifiable {
        let id = UUID()
        enum ActionType: String, Equatable {
            case keep
            case bin
            case stack
            case cloud
            case move
        }
        
        let type: ActionType
        let file: DesktopFile
        let previousIndex: Int
        let fileOriginalIndex: Int?
        let decision: FileDecision?
        let movedToURL: URL?
        let destinationId: UUID?
    }
    
    @Published var actionHistory: [Action] = []
    private let maxHistorySize = 50
    
    private func recordAction(_ type: Action.ActionType, file: DesktopFile, originalIndex: Int? = nil, decision: FileDecision? = nil, movedToURL: URL? = nil, destinationId: UUID? = nil) {
        let action = Action(
            type: type,
            file: file,
            previousIndex: currentFileIndex,
            fileOriginalIndex: originalIndex,
            decision: decision,
            movedToURL: movedToURL,
            destinationId: destinationId
        )
        actionHistory.append(action)
        
        // Limit history size
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }
    
    // MARK: - Undo / Redo
    
    func undoLastAction() -> Bool {
        guard let lastAction = actionHistory.popLast() else {
            return false
        }
        
        // Revert decision in files array
        if let index = files.firstIndex(where: { $0.id == lastAction.file.id }) {
            files[index].decision = nil
        }
        viewedFileIds.remove(lastAction.file.id)
        
        // Restore counters
        switch lastAction.type {
        case .keep:
            keptCount = max(0, keptCount - 1)
        case .bin:
            binnedCount = max(0, binnedCount - 1)
            reclaimedSpace = max(0, reclaimedSpace - lastAction.file.fileSize)
            if !immediateBinning {
                binnedFiles.removeAll { $0.id == lastAction.file.id }
            }
        case .stack:
            stackedFiles.removeAll { $0.id == lastAction.file.id }
        case .cloud:
            if let movedURL = lastAction.movedToURL {
                let destURL = cloudManager.resolvedURL(for: lastAction.destinationId)
                let accessing = destURL?.startAccessingSecurityScopedResource() ?? false
                defer { if accessing { destURL?.stopAccessingSecurityScopedResource() } }
                try? FileManager.default.moveItem(at: movedURL, to: lastAction.file.url)
            }
        case .move:
            if let movedURL = lastAction.movedToURL {
                try? FileManager.default.moveItem(at: movedURL, to: lastAction.file.url)
            }
        }
        
        // Restore index to the file we just undid
        if let newIndex = filteredFiles.firstIndex(where: { $0.id == lastAction.file.id }) {
            withAnimation {
                currentFileIndex = newIndex
            }
        }
        
        generateThumbnails(for: currentFileIndex)
        return true
    }
    
    func resetSession() {
        // Undo all actions in reverse order
        while !actionHistory.isEmpty {
            _ = undoLastAction()
        }
    }
    
    func undoDecision(for file: DesktopFile) {
        // Clear decision
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].decision = nil
        }
        viewedFileIds.remove(file.id)
        
        // Revert stats
        if let lastAction = actionHistory.last(where: { $0.file.id == file.id }) {
            switch lastAction.type {
            case .keep: keptCount = max(0, keptCount - 1)
            case .bin:
                binnedCount = max(0, binnedCount - 1)
                reclaimedSpace = max(0, reclaimedSpace - file.fileSize)
                if !immediateBinning { binnedFiles.removeAll { $0.id == file.id } }
            case .stack: stackedFiles.removeAll { $0.id == file.id }
            case .cloud:
                if let movedURL = lastAction.movedToURL {
                    let destURL = cloudManager.resolvedURL(for: lastAction.destinationId)
                    let accessing = destURL?.startAccessingSecurityScopedResource() ?? false
                    defer { if accessing { destURL?.stopAccessingSecurityScopedResource() } }
                    try? FileManager.default.moveItem(at: movedURL, to: file.url)
                }
            case .move:
                if let movedURL = lastAction.movedToURL {
                    try? FileManager.default.moveItem(at: movedURL, to: file.url)
                }
            }
            
            // Remove from history
            if let historyIndex = actionHistory.lastIndex(where: { $0.file.id == file.id }) {
                actionHistory.remove(at: historyIndex)
            }
        }
    }
    
    func canRedo() -> Bool {
        // Simple forward navigation for now, or true redo if we tracked redo stack.
        // User asked for "Forward button which does the opposite of redo/undo".
        // This implies navigating forward if we navigated back?
        // Or re-applying a stripped decision?
        // For simplicity, let's treat it as "Next File" for navigation,
        // or if we want full Redo, we need a redoStack.
        // Given the prompt "forward button which does the opposite", let's assume Navigation Forward.
        currentFileIndex < filteredFiles.count - 1
    }
    
    func goForward() {
        if currentFileIndex < filteredFiles.count - 1 {
            withAnimation {
                currentFileIndex += 1
            }
            generateThumbnails(for: currentFileIndex)
        }
    }
    
    func goBack() {
        if currentFileIndex > 0 {
            withAnimation {
                currentFileIndex -= 1
            }
            generateThumbnails(for: currentFileIndex)
        }
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
        // Don't reset session - just clear the stack
    }
    
    private func moveToNext() {
        withAnimation {
            // Don't increment if we're already at the end
            if currentFileIndex < filteredFiles.count {
                currentFileIndex += 1
            }
        }
        // Preload more as we move
        generateThumbnails(for: currentFileIndex)
        
        if isFinished && !folderStack.isEmpty {
            returnToParentFolder()
        }
    }
    
    var isInSubfolder: Bool {
        !folderStack.isEmpty
    }
    
    var parentFolderName: String {
        folderStack.last?.url.lastPathComponent ?? "Back"
    }

    func skipFolder(_ file: DesktopFile) {
        print("Folder decision: skip \(file.url.path)")
        if let removedIndex = filteredFiles.firstIndex(where: { $0.id == file.id }) {
            files.removeAll { $0.id == file.id }
            if filteredFiles.isEmpty {
                if folderStack.isEmpty {
                    promptForFolderAndLoad()
                } else {
                    returnToParentFolder()
                }
                return
            }
            currentFileIndex = min(removedIndex, filteredFiles.count - 1)
            generateThumbnails(for: currentFileIndex)
        } else {
            moveToNext()
        }
    }

    func enterFolder(_ file: DesktopFile) {
        guard file.fileType == .folder else { return }
        print("Folder decision: dive into \(file.url.path)")
        let context = FolderContext(
            url: selectedFolderURL ?? file.url,
            files: files,
            currentFileIndex: currentFileIndex,
            selectedFileTypeFilter: selectedFileTypeFilter,
            totalFilesCount: totalFilesCount,
            suggestionCache: suggestionCache,
            lastSuggestionFileId: lastSuggestionFileId,
            currentFileSuggestions: currentFileSuggestions,
            thumbnailGenerationInProgress: thumbnailGenerationInProgress
        )
        folderStack.append(context)
        
        selectedFolderURL = file.url
        FileScanner.shared.useCustomURL(file.url)
        loadFiles()
    }

    func returnToParentFolder() {
        guard let context = folderStack.popLast() else { return }
        selectedFolderURL = context.url
        FileScanner.shared.useCustomURL(context.url)
        files = context.files
        currentFileIndex = min(context.currentFileIndex, files.count)
        selectedFileTypeFilter = context.selectedFileTypeFilter
        totalFilesCount = context.totalFilesCount
        suggestionCache = context.suggestionCache
        lastSuggestionFileId = context.lastSuggestionFileId
        currentFileSuggestions = context.currentFileSuggestions
        thumbnailGenerationInProgress = context.thumbnailGenerationInProgress
        updateBreadcrumbs()
        generateThumbnails(for: currentFileIndex)
    }

    private func updateBreadcrumbs() {
        let crumbs = folderStack.map { $0.url.lastPathComponent } + [selectedFolderURL?.lastPathComponent ?? "Folder"]
        breadcrumbText = crumbs.joined(separator: " > ")
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
        reclaimedSpace = 0 // Reset reclaimed space since files are now in trash
        // Don't reset session - just clear the bin
    }
    
    func restoreFromBin(_ file: DesktopFile) {
        // Remove from bin
        binnedFiles.removeAll { $0.id == file.id }
        
        // Restore counters
        binnedCount = max(0, binnedCount - 1)
        reclaimedSpace = max(0, reclaimedSpace - file.fileSize)
        
        // Add back to files array at the beginning (so user can review it)
        files.insert(file, at: 0)
        
        // If we're at the end, go back to review this file
        if currentFileIndex >= filteredFiles.count {
            currentFileIndex = 0
        }
        
        // Regenerate thumbnails
        generateThumbnails(for: currentFileIndex)
    }
    
    func removeFromBin(_ file: DesktopFile) {
        // Remove from bin
        binnedFiles.removeAll { $0.id == file.id }
        
        // Restore counters
        binnedCount = max(0, binnedCount - 1)
        reclaimedSpace = max(0, reclaimedSpace - file.fileSize)
        
        // Move to trash immediately
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            print("Moved to trash: \(file.name)")
        } catch {
            print("Failed to trash file \(file.name): \(error)")
        }
    }
    
    var formattedReclaimedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: reclaimedSpace)
    }
    
    func triggerShake(for fileId: UUID) {
        // Cancel previous task
        shakeTask?.cancel()
        
        // Set ID to trigger shake
        withAnimation {
            shakingFileId = fileId
        }
        
        // Auto-stop after 3 seconds
        shakeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            if !Task.isCancelled && shakingFileId == fileId {
                withAnimation {
                    shakingFileId = nil
                }
            }
        }
    }
    
    func stopShake() {
        shakeTask?.cancel()
        withAnimation {
            shakingFileId = nil
        }
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
        
        // Sync thumbnails from main files array and generate missing ones
        var syncedFiles: [DesktopFile] = []
        for var file in groupFiles {
            // Look up the file in the main files array to get its thumbnail if it exists
            if let mainFileIndex = files.firstIndex(where: { $0.id == file.id }),
               let thumbnail = files[mainFileIndex].thumbnail {
                file.thumbnail = thumbnail
            }
            syncedFiles.append(file)
        }
        
        groupReviewFiles = syncedFiles
        groupReviewSuggestion = suggestion
        showGroupReview = true
        
        // Generate thumbnails for any files in the group that don't have them yet
        generateThumbnailsForGroupReview()
    }
    
    private func generateThumbnailsForGroupReview() {
        for (index, file) in groupReviewFiles.enumerated() {
            // Skip if already generating or already has thumbnail
            guard !thumbnailGenerationInProgress.contains(file.id),
                  file.thumbnail == nil else {
                continue
            }
            
            // Mark as in progress
            thumbnailGenerationInProgress.insert(file.id)
            
            FileScanner.shared.generateThumbnail(for: file) { [weak self] image in
                guard let self = self else { return }
                
                // Update on main thread
                Task { @MainActor in
                    // Update the thumbnail in groupReviewFiles (reassign array to trigger SwiftUI update)
                    if index < self.groupReviewFiles.count,
                       self.groupReviewFiles[index].id == file.id {
                        var updatedFiles = self.groupReviewFiles
                        updatedFiles[index].thumbnail = image
                        self.groupReviewFiles = updatedFiles
                    }
                    
                    // Also update in main files array if it exists there
                    if let mainFileIndex = self.files.firstIndex(where: { $0.id == file.id }) {
                        var updatedMainFiles = self.files
                        updatedMainFiles[mainFileIndex].thumbnail = image
                        self.files = updatedMainFiles
                    }
                    
                    self.thumbnailGenerationInProgress.remove(file.id)
                }
            }
        }
    }
    
    func getGroupStats() -> (totalSize: Int64, dateRange: String?) {
        let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize }
        
        // Get date range
        let dates = groupReviewFiles.compactMap { file -> Date? in
            try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date
        }
        
        guard let earliest = dates.min(), let latest = dates.max() else {
            return (totalSize, nil)
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            formatter.dateStyle = .none
            return (totalSize, "Today \(formatter.string(from: earliest)) - \(formatter.string(from: latest))")
        } else {
            return (totalSize, "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))")
        }
    }
    
    func getSmartActions() -> [SmartAction] {
        guard let suggestion = groupReviewSuggestion else { return [] }
        
        var actions: [SmartAction] = []
        let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize }
        let sizeMB = Double(totalSize) / (1024 * 1024)
        
        switch suggestion.type {
        case .duplicate(let count, _):
            // Sort by date (newest first)
            let sorted = groupReviewFiles.sorted { file1, file2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }
            
            actions.append(SmartAction(
                title: "Keep newest, delete others",
                description: "Keep 1 file, delete \(count - 1)",
                icon: "clock.fill",
                action: {
                    // Re-verify files existence
                    let currentFiles = self.groupReviewFiles.filter { f in sorted.contains(where: { $0.id == f.id }) }
                    let currentSorted = currentFiles.sorted { file1, file2 in
                         let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                         let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                         return date1 > date2
                     }
                    
                    guard let newest = currentSorted.first else { return }
                    
                    let toKeep = [newest]
                    let toBin = Array(currentSorted.dropFirst())
                    
                    self.keepGroupFiles(toKeep)
                    self.binGroupFiles(toBin)
                }
            ))
            
        case .similarNames(_, let count, _):
            // For screenshots, suggest keeping recent ones
            let sorted = groupReviewFiles.sorted { file1, file2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }
            
            let keepCount = min(5, count)
            actions.append(SmartAction(
                title: "Keep newest \(keepCount), delete rest",
                description: "Free \(String(format: "%.1f", sizeMB * Double(count - keepCount) / Double(count))) MB",
                icon: "sparkles",
                action: {
                    let toKeep = Array(sorted.prefix(keepCount))
                    let toBin = Array(sorted.dropFirst(keepCount))
                    self.keepGroupFiles(toKeep)
                    self.binGroupFiles(toBin)
                }
            ))
            
            // Delete all older than 1 week
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let oldFiles = groupReviewFiles.filter { file in
                guard let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                    return false
                }
                return date < oneWeekAgo
            }
            
            if !oldFiles.isEmpty {
                let oldSizeMB = Double(oldFiles.reduce(0) { $0 + $1.fileSize }) / (1024 * 1024)
                actions.append(SmartAction(
                    title: "Delete files older than 1 week",
                    description: "\(oldFiles.count) files, \(String(format: "%.1f", oldSizeMB)) MB",
                    icon: "calendar.badge.clock",
                    action: {
                        self.binGroupFiles(oldFiles)
                    }
                ))
            }
            
        case .sameSession(_, _):
            actions.append(SmartAction(
                title: "Keep all (created together)",
                description: "These files are related",
                icon: "checkmark.circle.fill",
                action: {
                    self.keepGroupFiles(self.groupReviewFiles)
                }
            ))
            
            actions.append(SmartAction(
                title: "Delete all",
                description: "Free \(String(format: "%.1f", sizeMB)) MB",
                icon: "trash.fill",
                action: {
                    self.binGroupFiles(self.groupReviewFiles)
                }
            ))
            
        default:
            break
        }
        
        return actions
    }
    
    func binStackedFiles(_ filesToBin: [DesktopFile]) {
        for file in filesToBin {
            // Remove from stack
            stackedFiles.removeAll { $0.id == file.id }
            
            // Trash
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                binnedCount += 1
                reclaimedSpace += filesToBin.reduce(0) { $0 + $1.fileSize }
                print("Stacked file moved to trash: \(file.name)")
            } catch {
                print("Failed to trash stacked file \(file.name): \(error)")
            }
        }
    }
    
    func keepStackedFiles(_ filesToKeep: [DesktopFile]) {
        for file in filesToKeep {
            // Remove from stack
            stackedFiles.removeAll { $0.id == file.id }
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files[index].decision = .kept
                keptCount += 1
            }
        }
    }
    
    func keepGroupFiles(_ filesToKeep: [DesktopFile]) {
        guard !filesToKeep.isEmpty else { return }
        
        for file in filesToKeep {
            // Find in main array and mark as kept
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files[index].decision = .kept
                keptCount += 1
                recordAction(.keep, file: file, decision: .kept)
            }
            suggestionCache.removeValue(forKey: file.id)
        }
        
        // Remove kept files from group review
        groupReviewFiles.removeAll { file in filesToKeep.contains { $0.id == file.id } }
        
        // If all files processed, exit group review
        if groupReviewFiles.isEmpty {
            showGroupReview = false
            groupReviewSuggestion = nil
        }
    }
    
    func binGroupFiles(_ filesToBin: [DesktopFile]) {
        guard !filesToBin.isEmpty else { return }
        
        for file in filesToBin {
            // Find in main array and mark as binned
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files[index].decision = .binned
                binnedCount += 1
                reclaimedSpace += file.fileSize
                
                if immediateBinning {
                    do {
                        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                    } catch {
                        print("Failed to trash from group: \(error)")
                    }
                } else {
                    binnedFiles.append(file)
                }
                
                recordAction(.bin, file: file, decision: .binned)
            }
            suggestionCache.removeValue(forKey: file.id)
        }
        
        // Remove binned files from group review
        groupReviewFiles.removeAll { file in filesToBin.contains { $0.id == file.id } }
        
        // If all files processed, exit group review
        if groupReviewFiles.isEmpty {
            showGroupReview = false
            groupReviewSuggestion = nil
        }
    }
}
