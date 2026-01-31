import Foundation
import Combine
import AppKit

class DeclutterViewModel: ObservableObject {
    @Published var files: [DesktopFile] = []
    @Published var errorMessage: String?
    @Published var currentFileIndex: Int?
    @Published var selectedFolderURL: URL?

    /// True while an Accept/Dump action is being applied, to prevent double-processing.
    @Published var isPerformingFileAction: Bool = false

    /// True while the folder picker is being presented.
    private var isPresentingFolderPicker: Bool = false

    /// ISO-8601 timestamp formatter for terminal logs.
    private let logFormatter = ISO8601DateFormatter()

    /// Log helper (prints to terminal when running via `swift run` / Xcode).
    private func log(_ message: String) {
        let ts = logFormatter.string(from: Date())
        print("[DesktopDeclutter \(ts)] \(message)")
    }

    /// Prompt the user to choose a folder to scan.
    ///
    /// Uses `NSOpenPanel.begin` (non-blocking) so it works reliably at app launch.
    @MainActor
    func promptForFolderAndLoad() {
        guard !isPresentingFolderPicker else {
            log("Folder picker already presenting; ignoring duplicate request.")
            return
        }
        isPresentingFolderPicker = true

        log("Presenting folder picker…")

        // Bring the app to front so the open panel is visible.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose a folder to declutter"
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard let self else { return }
            Task { @MainActor in
                self.isPresentingFolderPicker = false

                if response == .OK, let url = panel.url {
                    self.selectedFolderURL = url
                    self.log("Folder selected: \(url.path)")

                    // Update scanner to use the chosen folder.
                    FileScanner.shared.useCustomURL(url)

                    // Load files from the newly-selected folder.
                    self.loadFiles()
                } else {
                    self.log("Folder picker cancelled.")
                }
            }
        }
    }

    /// Prompt for a folder only once per app run (if nothing has been selected yet).
    @MainActor
    func promptForFolderIfNeeded() {
        guard !hasPromptedForFolder else { return }
        hasPromptedForFolder = true

        if selectedFolderURL == nil {
            log("No folder selected yet; prompting on launch.")
            promptForFolderAndLoad()
        } else {
            log("Folder already selected; skipping launch prompt.")
        }
    }

    func loadFiles() {
        log("Scanning folder: \(selectedFolderURL?.path ?? "(default)")")
        do {
            let loadedFiles = try FileScanner.shared.scanCurrentFolder()
            DispatchQueue.main.async {
                self.files = loadedFiles
                self.currentFileIndex = self.files.isEmpty ? nil : 0
                self.log("Scan complete. Found \(loadedFiles.count) items.")
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.log("Scan failed: \(error.localizedDescription)")
            }
        }
    }

    func acceptCurrentFile() {
        guard !isPerformingFileAction else {
            log("Ignoring action: already performing a file operation.")
            return
        }
        isPerformingFileAction = true
        defer { isPerformingFileAction = false }

        if let idx = currentFileIndex, files.indices.contains(idx) {
            log("Action START: ACCEPT on index \(idx): \(files[idx].name)")
        } else {
            log("Action START: ACCEPT but currentFileIndex is invalid.")
        }

        // Implementation for accepting the file (e.g., keep as is, or move to accepted folder)
        // After operation completes:
        log("Action END: ACCEPT")

        currentFileIndex = (currentFileIndex ?? 0) + 1
        if let idx = currentFileIndex, files.indices.contains(idx) {
            log("Next selected index \(idx): \(files[idx].name)")
        } else {
            log("No next file selected (end of list or invalid index).")
        }
    }

    func dumpCurrentFile() {
        guard !isPerformingFileAction else {
            log("Ignoring action: already performing a file operation.")
            return
        }
        isPerformingFileAction = true
        defer { isPerformingFileAction = false }

        if let idx = currentFileIndex, files.indices.contains(idx) {
            log("Action START: DUMP on index \(idx): \(files[idx].name)")
        } else {
            log("Action START: DUMP but currentFileIndex is invalid.")
        }

        // Implementation for dumping the file (e.g., move to trash or delete)
        // After operation completes:
        log("Action END: DUMP")

        currentFileIndex = (currentFileIndex ?? 0) + 1
        if let idx = currentFileIndex, files.indices.contains(idx) {
            log("Next selected index \(idx): \(files[idx].name)")
        } else {
            log("No next file selected (end of list or invalid index).")
        }
    }
}
