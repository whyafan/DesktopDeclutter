import Foundation

enum SuggestionType: Equatable {
    case duplicate(count: Int, files: [DesktopFile])
    case similarNames(pattern: String, count: Int, files: [DesktopFile])
    case oldFile(years: Double)
    case largeFile(sizeMB: Double)
    case sameSession(count: Int, files: [DesktopFile])
    case temporaryFile
    
    static func == (lhs: SuggestionType, rhs: SuggestionType) -> Bool {
        switch (lhs, rhs) {
        case (.duplicate(let lCount, _), .duplicate(let rCount, _)):
            return lCount == rCount
        case (.similarNames(let lPattern, let lCount, _), .similarNames(let rPattern, let rCount, _)):
            return lPattern == rPattern && lCount == rCount
        case (.oldFile(let lYears), .oldFile(let rYears)):
            return lYears == rYears
        case (.largeFile(let lSize), .largeFile(let rSize)):
            return lSize == rSize
        case (.sameSession(let lCount, _), .sameSession(let rCount, _)):
            return lCount == rCount
        case (.temporaryFile, .temporaryFile):
            return true
        default:
            return false
        }
    }
}

struct FileSuggestion: Identifiable, Equatable {
    let id = UUID()
    let type: SuggestionType
    let priority: Int // Higher = more important
    let message: String
    let actionHint: String?
    
    static func == (lhs: FileSuggestion, rhs: FileSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

class SuggestionDetector {
    static let shared = SuggestionDetector()
    
    // Async version for background processing
    func detectSuggestionsAsync(for file: DesktopFile, in allFiles: [DesktopFile]) async -> [FileSuggestion] {
        return await withTaskGroup(of: FileSuggestion?.self) { group in
            var suggestions: [FileSuggestion] = []
            
            // Exclude current file from comparisons
            let otherFiles = allFiles.filter { $0.id != file.id }
            
            // Run detection tasks in parallel
            group.addTask {
                await self.detectDuplicatesAsync(for: file, in: otherFiles)
            }
            
            group.addTask {
                await self.detectSimilarNamesAsync(for: file, in: otherFiles)
            }
            
            group.addTask {
                await self.detectOldFileAsync(file)
            }
            
            group.addTask {
                await self.detectLargeFileAsync(file)
            }
            
            group.addTask {
                await self.detectSameSessionAsync(for: file, in: otherFiles)
            }
            
            group.addTask {
                await self.detectTemporaryFileAsync(file)
            }
            
            // Collect results
            for await suggestion in group {
                if let suggestion = suggestion {
                    suggestions.append(suggestion)
                }
            }
            
            // Sort by priority (highest first)
            return suggestions.sorted { $0.priority > $1.priority }
        }
    }
    
    // Synchronous version (kept for compatibility, but should use async)
    func detectSuggestions(for file: DesktopFile, in allFiles: [DesktopFile]) -> [FileSuggestion] {
        var suggestions: [FileSuggestion] = []
        
        // Exclude current file from comparisons
        let otherFiles = allFiles.filter { $0.id != file.id }
        
        // 1. Duplicate detection (exact filename + size match)
        if let duplicateSuggestion = detectDuplicates(for: file, in: otherFiles) {
            suggestions.append(duplicateSuggestion)
        }
        
        // 2. Similar name patterns
        if let similarSuggestion = detectSimilarNames(for: file, in: otherFiles) {
            suggestions.append(similarSuggestion)
        }
        
        // 3. Old file detection
        if let oldFileSuggestion = detectOldFile(file) {
            suggestions.append(oldFileSuggestion)
        }
        
        // 4. Large file detection
        if let largeFileSuggestion = detectLargeFile(file) {
            suggestions.append(largeFileSuggestion)
        }
        
        // 5. Same session detection
        if let sessionSuggestion = detectSameSession(for: file, in: otherFiles) {
            suggestions.append(sessionSuggestion)
        }
        
        // 6. Temporary file detection
        if let tempSuggestion = detectTemporaryFile(file) {
            suggestions.append(tempSuggestion)
        }
        
        // Sort by priority (highest first)
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Detection Methods
    
    private func detectDuplicates(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? {
        let duplicates = otherFiles.filter { otherFile in
            otherFile.name == file.name && otherFile.fileSize == file.fileSize
        }
        
        if duplicates.count > 0 {
            return FileSuggestion(
                type: .duplicate(count: duplicates.count + 1, files: [file] + duplicates),
                priority: 10,
                message: "\(duplicates.count + 1) copies of this file",
                actionHint: "Keep one, delete others?"
            )
        }
        return nil
    }
    
    private func detectSimilarNames(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? {
        let fileName = file.name.lowercased()
        
        // Pattern detection
        var pattern: String?
        var matches: [DesktopFile] = []
        
        // CleanShot pattern: cleanshot_xxxxx
        if fileName.contains("cleanshot_") {
            pattern = "CleanShot screenshots"
            matches = otherFiles.filter { $0.name.lowercased().contains("cleanshot_") }
        }
        // Screen Shot pattern
        else if fileName.contains("screen shot") || fileName.contains("screenshot") {
            pattern = "Screenshots"
            matches = otherFiles.filter {
                let name = $0.name.lowercased()
                return name.contains("screen shot") || name.contains("screenshot")
            }
        }
        // Numbered sequence: _001, _002, _v1, _v2, etc.
        else if let numberedPattern = detectNumberedSequence(fileName) {
            pattern = numberedPattern.pattern
            matches = otherFiles.filter { otherFile in
                detectNumberedSequence(otherFile.name.lowercased())?.base == numberedPattern.base
            }
        }
        // Date pattern: IMG_2024_01_25, photo_20240125
        else if let datePattern = detectDatePattern(fileName) {
            pattern = "Files from \(datePattern)"
            matches = otherFiles.filter { otherFile in
                detectDatePattern(otherFile.name.lowercased()) == datePattern
            }
        }
        
        if let pattern = pattern, matches.count > 2 {
            return FileSuggestion(
                type: .similarNames(pattern: pattern, count: matches.count + 1, files: [file] + matches),
                priority: 8,
                message: "\(matches.count + 1) \(pattern.lowercased())",
                actionHint: "Review together?"
            )
        }
        
        return nil
    }
    
    private func detectNumberedSequence(_ fileName: String) -> (base: String, pattern: String)? {
        // Pattern: name_001, name_002
        if let match = fileName.range(of: #"_\d{3,}"#, options: .regularExpression) {
            let base = String(fileName[..<match.lowerBound])
            return (base, "Numbered sequence")
        }
        // Pattern: name_v1, name_v2
        if let match = fileName.range(of: #"_v\d+"#, options: .regularExpression) {
            let base = String(fileName[..<match.lowerBound])
            return (base, "Versioned files")
        }
        // Pattern: name (1), name (2)
        if let match = fileName.range(of: #"\s\(\d+\)"#, options: .regularExpression) {
            let base = String(fileName[..<match.lowerBound])
            return (base, "Numbered copies")
        }
        return nil
    }
    
    private func detectDatePattern(_ fileName: String) -> String? {
        // Pattern: IMG_2024_01_25, 2024-01-25, 20240125
        let patterns = [
            #"\d{4}[-_]\d{2}[-_]\d{2}"#,
            #"\d{8}"#
        ]
        
        for pattern in patterns {
            if let range = fileName.range(of: pattern, options: .regularExpression) {
                return String(fileName[range])
            }
        }
        return nil
    }
    
    private func detectOldFile(_ file: DesktopFile) -> FileSuggestion? {
        guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
            return nil
        }
        
        let yearsAgo = Date().timeIntervalSince(creationDate) / (365.25 * 24 * 60 * 60)
        
        if yearsAgo >= 2 {
            let years = Int(yearsAgo)
            return FileSuggestion(
                type: .oldFile(years: yearsAgo),
                priority: 6,
                message: "Created \(years) year\(years > 1 ? "s" : "") ago",
                actionHint: "Still needed?"
            )
        } else if yearsAgo >= 1 {
            return FileSuggestion(
                type: .oldFile(years: yearsAgo),
                priority: 4,
                message: "Created over a year ago",
                actionHint: nil
            )
        }
        
        return nil
    }
    
    // Async versions
    private func detectDuplicatesAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        return detectDuplicates(for: file, in: otherFiles)
    }
    
    private func detectSimilarNamesAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        return detectSimilarNames(for: file, in: otherFiles)
    }
    
    private func detectOldFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        // Run file system access on background thread
        return await Task.detached {
            guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                return nil
            }
            
            let yearsAgo = Date().timeIntervalSince(creationDate) / (365.25 * 24 * 60 * 60)
            
            if yearsAgo >= 2 {
                let years = Int(yearsAgo)
                return FileSuggestion(
                    type: .oldFile(years: yearsAgo),
                    priority: 6,
                    message: "Created \(years) year\(years > 1 ? "s" : "") ago",
                    actionHint: "Still needed?"
                )
            } else if yearsAgo >= 1 {
                return FileSuggestion(
                    type: .oldFile(years: yearsAgo),
                    priority: 4,
                    message: "Created over a year ago",
                    actionHint: nil
                )
            }
            
            return nil
        }.value
    }
    
    private func detectLargeFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        return detectLargeFile(file)
    }
    
    private func detectSameSessionAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        // Run file system access on background thread
        return await Task.detached {
            guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                return nil
            }
            
            // Files created within 5 minutes
            let sessionWindow: TimeInterval = 5 * 60
            
            let sessionFiles = otherFiles.filter { otherFile in
                guard let otherDate = try? FileManager.default.attributesOfItem(atPath: otherFile.url.path)[.creationDate] as? Date else {
                    return false
                }
                return abs(creationDate.timeIntervalSince(otherDate)) <= sessionWindow
            }
            
            if sessionFiles.count >= 3 {
                return FileSuggestion(
                    type: .sameSession(count: sessionFiles.count + 1, files: [file] + sessionFiles),
                    priority: 5,
                    message: "\(sessionFiles.count + 1) files from same session",
                    actionHint: "Created together - review together?"
                )
            }
            
            return nil
        }.value
    }
    
    private func detectTemporaryFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        return detectTemporaryFile(file)
    }
    
    private func detectLargeFile(_ file: DesktopFile) -> FileSuggestion? {
        let sizeMB = Double(file.fileSize) / (1024 * 1024)
        
        if sizeMB >= 500 {
            return FileSuggestion(
                type: .largeFile(sizeMB: sizeMB),
                priority: 7,
                message: "\(String(format: "%.1f", sizeMB)) MB - Large file",
                actionHint: "Taking up significant space"
            )
        } else if sizeMB >= 100 {
            return FileSuggestion(
                type: .largeFile(sizeMB: sizeMB),
                priority: 5,
                message: "\(String(format: "%.1f", sizeMB)) MB",
                actionHint: nil
            )
        }
        
        return nil
    }
    
    private func detectSameSession(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? {
        guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
            return nil
        }
        
        // Files created within 5 minutes
        let sessionWindow: TimeInterval = 5 * 60
        
        let sessionFiles = otherFiles.filter { otherFile in
            guard let otherDate = try? FileManager.default.attributesOfItem(atPath: otherFile.url.path)[.creationDate] as? Date else {
                return false
            }
            return abs(creationDate.timeIntervalSince(otherDate)) <= sessionWindow
        }
        
        if sessionFiles.count >= 3 {
            return FileSuggestion(
                type: .sameSession(count: sessionFiles.count + 1, files: [file] + sessionFiles),
                priority: 5,
                message: "\(sessionFiles.count + 1) files from same session",
                actionHint: "Created together - review together?"
            )
        }
        
        return nil
    }
    
    private func detectTemporaryFile(_ file: DesktopFile) -> FileSuggestion? {
        let fileName = file.name.lowercased()
        let tempExtensions = ["tmp", "cache", "log", "bak", "old"]
        let tempPatterns = ["temp", "cache", "backup", "~"]
        
        let isTempExtension = tempExtensions.contains(file.url.pathExtension.lowercased())
        let hasTempPattern = tempPatterns.contains { fileName.contains($0) }
        
        if isTempExtension || hasTempPattern {
            return FileSuggestion(
                type: .temporaryFile,
                priority: 9,
                message: "Looks like a temporary file",
                actionHint: "Safe to delete?"
            )
        }
        
        return nil
    }
}
