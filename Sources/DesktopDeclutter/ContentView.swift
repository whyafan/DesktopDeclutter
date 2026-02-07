import SwiftUI
import QuickLookUI

struct ContentView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @StateObject private var cloudManager = CloudManager.shared
    
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showStackedFiles = false
    @State private var showBinnedFiles = false
    @State private var showFilters = false
    @State private var window: NSWindow?


    
    var body: some View {
        Group {
            if viewModel.selectedFolderURL == nil {
                VStack(spacing: 16) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("Choose a folder to begin")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Desktop Declutter needs a folder to scan. Please select one to continue.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                    
                    Button(action: {
                        viewModel.promptForFolderAndLoad()
                    }) {
                        Text("Choose Folder")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(Color.blue.opacity(0.15))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                }
            } else {
                // MAIN SPLIT VIEW LAYOUT
                HStack(spacing: 0) {
                    // LEFT SIDEBAR: Persistent Folder Structure
                    FolderStructureView(viewModel: viewModel)
                    
                    Divider()
                        .ignoresSafeArea()
                    
                    // RIGHT CONTENT AREA: Dynamic Content
                    ZStack {
                        // Background
                        VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            // Toolbar (Top of Right Pane)
                            HStack(spacing: 12) {
                                // Undo
                                if viewModel.canUndo {
                                    Button(action: { _ = viewModel.undoLastAction() }) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                            .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                    }
                                    .buttonStyle(.plain)
                                    .help("Undo (⌘Z)")
                                }
                                

                                
                                // History
                                Button(action: { showHistory.toggle() }) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, height: 28)
                                        .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                                    HistoryView(viewModel: viewModel, isPresented: $showHistory)
                                }
                                
                                // Settings
                                Button(action: { showSettings.toggle() }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, height: 28)
                                        .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                }
                                .buttonStyle(.plain)

                                .sheet(isPresented: $showSettings) {
                                    SettingsView(isPresented: $showSettings, viewModel: viewModel)
                                }
                                
                                Spacer()
                                
                                // Progress Bar
                                VStack(spacing: 4) {
                                    ProgressView(value: Double(viewModel.currentFileIndex), total: Double(max(viewModel.filteredFiles.count, 1)))
                                        .progressViewStyle(.linear)
                                        .frame(width: 180)
                                    HStack(spacing: 4) {
                                        Text("\(viewModel.currentFileIndex)").font(.system(size: 11, weight: .semibold))
                                        Text("of").font(.system(size: 11)).foregroundColor(.secondary)
                                        Text("\(viewModel.filteredFiles.count)").font(.system(size: 11, weight: .semibold))
                                    }
                                }
                                
                                Spacer()
                                
                                // Filter
                                Button(action: { showFilters.toggle() }) {
                                    Image(systemName: viewModel.selectedFileTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(viewModel.selectedFileTypeFilter != nil ? .blue : .secondary)
                                        .frame(width: 28, height: 28)
                                        .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showFilters, arrowEdge: .top) {
                                    FilterView(viewModel: viewModel).frame(width: 200).padding(12)
                                }
                                
                                // Binned Files Toggle
                                if !viewModel.immediateBinning && !viewModel.binnedFiles.isEmpty {
                                    Button(action: { showBinnedFiles.toggle(); showStackedFiles = false }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash.fill").font(.system(size: 13, weight: .medium))
                                            Text("\(viewModel.binnedFiles.count)").font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.red.opacity(0.15)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Stacked Files Toggle
                                if !viewModel.stackedFiles.isEmpty {
                                    Button(action: { showStackedFiles.toggle(); showBinnedFiles = false }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.stack.fill").font(.system(size: 13, weight: .medium))
                                            Text("\(viewModel.stackedFiles.count)").font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(showStackedFiles ? .white : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(showStackedFiles ? Color.blue : Color(nsColor: .quaternaryLabelColor).opacity(0.3)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
                            
                            Divider().opacity(0.2)
                            
                            // MAIN CONTENT AREA
                            ZStack {
                                if let error = viewModel.errorMessage {
                                    // Error View
                                    VStack(spacing: 20) {
                                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                                        Text(error).multilineTextAlignment(.center)
                                        Button("Retry") { viewModel.loadFiles() }
                                    }
                                } else if showStackedFiles {
                                    StackedFilesView(viewModel: viewModel)
                                } else if showBinnedFiles {
                                    BinnedFilesView(viewModel: viewModel)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else if viewModel.showGroupReview {
                                    GroupReviewView(viewModel: viewModel)
                                } else if !viewModel.isFinished {
                                    if viewModel.isGridMode {
                                        // GALLERY / GRID VIEW
                                        GalleryGridView(viewModel: viewModel)
                                    } else if let file = viewModel.currentFile {
                                        if file.fileType == .folder {
                                            FolderActionView(viewModel: viewModel, folder: file)
                                        } else {
                                            // Card View for File
                                            ZStack {
                                                CardView(
                                                    file: file,
                                                    suggestions: viewModel.currentFileSuggestions,
                                                    onKeep: { withAnimation { viewModel.keepCurrentFile() } },
                                                    onBin: { withAnimation { viewModel.binCurrentFile() } },
                                                    onPreview: { QuickLookHelper.shared.preview(url: file.url) },
                                                    onSuggestionTap: { viewModel.startGroupReview(for: $0) }
                                                )
                                                .rotationEffect(.degrees(viewModel.shakingFileId == file.id ? 2 : 0))
                                                .animation(viewModel.shakingFileId == file.id ? .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default, value: viewModel.shakingFileId)
                                                .onHover { isHovered in
                                                    if isHovered && viewModel.shakingFileId == file.id {
                                                        viewModel.stopShake()
                                                    }
                                                }
                                                .overlay {
                                                    if let decision = file.decision {
                                                        ZStack {
                                                            Color.black.opacity(0.3)
                                                                .cornerRadius(16)
                                                            Image(systemName: decision == .kept ? "checkmark.circle.fill" : (decision == .binned ? "trash.circle.fill" : (decision == .cloud ? "icloud.and.arrow.up.fill" : "square.stack.3d.up.fill")))
                                                                .font(.system(size: 80))
                                                                .foregroundColor(.white)
                                                                .shadow(radius: 10)
                                                        }
                                                        .allowsHitTesting(false)
                                                    }
                                                }
                                                .padding(.bottom, 60) // Space for FABs
                                                
                                                // Floating Action Buttons
                                                if !viewModel.showGroupReview {
                                                    VStack {
                                                        Spacer()
                                                        HStack(spacing: 30) {
                                                            // Undo Button
                                                            Button(action: { withAnimation { _ = viewModel.undoLastAction() } }) {
                                                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                                                    .resizable()
                                                                    .frame(width: 50, height: 50)
                                                                    .foregroundColor(viewModel.canUndo ? .orange : .gray.opacity(0.3))
                                                                    .background(Circle().fill(Color.white).shadow(radius: 4))
                                                            }
                                                            .buttonStyle(.plain)
                                                            .disabled(!viewModel.canUndo)
                                                            .help("Undo (Cmd+Z)")
                                                            
                                                            // Bin
                                                            FloatingActionButton(icon: "trash.fill", shortcut: "←", color: .red) {
                                                                withAnimation { viewModel.binCurrentFile() }
                                                            }
                                                            .opacity(file.decision != nil ? 0.5 : 1.0)
                                                            
                                                            // Cloud
                                                            if cloudManager.activeDestination != nil {
                                                                FloatingActionButton(icon: "icloud.and.arrow.up.fill", shortcut: "C", color: .blue) {
                                                                    withAnimation { viewModel.moveToCloud(file) }
                                                                }
                                                                .opacity(file.decision != nil ? 0.5 : 1.0)
                                                            }
                                                            
                                                            // Keep
                                                            FloatingActionButton(icon: "checkmark.circle.fill", shortcut: "→", color: .green) {
                                                                withAnimation { viewModel.keepCurrentFile() }
                                                            }
                                                            .opacity(file.decision != nil ? 0.5 : 1.0)
                                                            
                                                            // Forward Button
                                                            Button(action: { withAnimation { viewModel.goForward() } }) {
                                                                Image(systemName: "arrow.right.circle.fill")
                                                                    .resizable()
                                                                    .frame(width: 50, height: 50)
                                                                    .foregroundColor(viewModel.canRedo() ? .blue : .gray.opacity(0.3))
                                                                    .background(Circle().fill(Color.white).shadow(radius: 4))
                                                            }
                                                            .buttonStyle(.plain)
                                                            .disabled(!viewModel.canRedo())
                                                            .help("Next File")
                                                        }
                                                        .padding(.bottom, 30)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // All Clean / Summary View
                                    VStack(spacing: 24) {
                                        if viewModel.binnedFiles.isEmpty {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 64, weight: .light))
                                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            Text("All Clean!").font(.title2).fontWeight(.semibold)
                                        } else {
                                            // Show Binned Files automatically if we have some? Or just summary.
                                            // User usually wants to review immediately if they finished.
                                            // Let's toggle to binned files review if there are files.
                                            BinnedFilesView(viewModel: viewModel)
                                        }
                                        
                                        if viewModel.binnedFiles.isEmpty {
                                            HStack(spacing: 24) {
                                                Button("Rescan Folder") { viewModel.loadFiles() }.buttonStyle(.plain).foregroundColor(.secondary)
                                                Button(action: { viewModel.promptForFolderAndLoad() }) {
                                                    HStack { Text("Scan Next Folder"); Image(systemName: "arrow.right") }
                                                        .padding(.horizontal, 20).padding(.vertical, 10)
                                                        .background(Capsule().fill(Color.blue))
                                                        .foregroundColor(.white)
                                                }.buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // Footer (Stats)
                            if !viewModel.isFinished {
                                HStack {
                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.red).frame(width: 6, height: 6)
                                            Text("Binned: \(viewModel.binnedCount)").font(.caption)
                                        }
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                            Text("Kept: \(viewModel.keptCount)").font(.caption)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
                            }
                        }
                    }
                    .frame(minWidth: 600, minHeight: 600)
                }
                .frame(minWidth: 900, minHeight: 600) // Forces larger window on update
            } // End of Else
        } // End of Group
        .frame(minWidth: 420, minHeight: 680)
        .background(WindowAccessor(window: $window))
        .background(QuickLookResponder())
        .onChange(of: viewModel.selectedFolderURL) { _ in
            DispatchQueue.main.async {
                if let window = window {
                    let currentFrame = window.frame
                    let newWidth = max(currentFrame.width, 1000)
                    let newHeight = max(currentFrame.height, 700)
                    if newWidth > currentFrame.width || newHeight > currentFrame.height {
                        window.setFrame(NSRect(x: currentFrame.minX, y: currentFrame.minY - (newHeight - currentFrame.height), width: newWidth, height: newHeight), display: true, animate: true)
                    }
                }
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
            viewModel.promptForFolderIfNeeded()
        }
        .onChange(of: viewModel.currentFile?.id) { _ in
            // Logic moved to View switching
        }
    }
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle Cmd+Z for undo
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 6 { // Z key
                    if viewModel.canUndo {
                        _ = viewModel.undoLastAction()
                        return nil
                    }
                }
                return nil // Let system handle other Cmd+key shortcuts
            }
            
            switch event.keyCode {
            case 123: // Left arrow
                if !viewModel.isFinished {
                    viewModel.binCurrentFile()
                    return nil
                }
            case 124: // Right arrow
                if !viewModel.isFinished {
                    viewModel.keepCurrentFile()
                    return nil
                }
            case 49: // Spacebar
                if !viewModel.isFinished, let file = viewModel.currentFile {
                    QuickLookHelper.shared.preview(url: file.url)
                    return nil
                }
            case 1: // S key
                if !viewModel.isFinished {
                    viewModel.stackCurrentFile()
                    return nil
                }
            case 36: // Return
                if let file = viewModel.currentFile, file.fileType == .folder {
                    viewModel.enterFolder(file)
                    return nil
                }
            default:
                break
            }
            
            return event
        }
    }
}

// MARK: - Quick Look Responder Helper

struct QuickLookResponder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = QuickLookResponderView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

class QuickLookResponderView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = QuickLookHelper.shared
        panel.delegate = QuickLookHelper.shared
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

// MARK: - Visual Effect View (Material Blur)

// VisualEffectView moved to its own file



// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let shortcut: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Blur background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Colored circle overlay
                Circle()
                    .fill(color.opacity(isHovered ? 0.9 : 0.85))
                    .frame(width: 64, height: 64)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                // Keyboard shortcut hint
                VStack {
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Binned Files View

struct BinnedFilesView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Binned Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.binnedFiles.count) file\(viewModel.binnedFiles.count == 1 ? "" : "s") pending review")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.emptyBin()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Move All to Trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(Color.red)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // File list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.binnedFiles) { file in
                        HStack(spacing: 12) {
                            // Thumbnail
                            Group {
                                if let thumb = file.thumbnail {
                                    Image(nsImage: thumb)
                                        .resizable()
                                } else {
                                    Image(nsImage: file.icon)
                                        .resizable()
                                }
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            }
                            
                            // File info
                            VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Actions
                            HStack(spacing: 8) {
                                Button(action: {
                                    QuickLookHelper.shared.preview(url: file.url)
                                }) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Preview")
                                
                                Button(action: {
                                    viewModel.restoreFromBin(file)
                                }) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Restore to review")
                                
                                Button(action: {
                                    viewModel.removeFromBin(file)
                                }) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.red.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Move to trash now")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Stacked Files View

struct StackedFilesView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @State private var selectedFiles: Set<UUID> = []
    @State private var hoveredFileId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stacked Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.stackedFiles.count) files waiting")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Select All / Deselect All
                Button(action: {
                    if selectedFiles.count == viewModel.stackedFiles.count {
                        selectedFiles.removeAll()
                    } else {
                        selectedFiles = Set(viewModel.stackedFiles.map { $0.id })
                    }
                }) {
                    Text(selectedFiles.count == viewModel.stackedFiles.count && !viewModel.stackedFiles.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.stackedFiles.isEmpty)
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // File grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.stackedFiles) { file in
                        FileGridCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.id),
                            isHovered: hoveredFileId == file.id,
                            isShaking: false,
                            onToggle: {
                                if selectedFiles.contains(file.id) {
                                    selectedFiles.remove(file.id)
                                } else {
                                    selectedFiles.insert(file.id)
                                }
                            },
                            onPreview: {
                                QuickLookHelper.shared.preview(url: file.url)
                            },
                            onHover: { hovering in
                                hoveredFileId = hovering ? file.id : nil
                            }
                        )
                    }
                }
                .padding()
            }
            
            // Footer Actions
            if !selectedFiles.isEmpty {
                VStack(spacing: 0) {
                    Divider().opacity(0.2)
                    HStack(spacing: 16) {
                        Button(action: {
                            let files = viewModel.stackedFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.keepStackedFiles(files)
                            selectedFiles.removeAll()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Keep Selected (\(selectedFiles.count))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            let files = viewModel.stackedFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.binStackedFiles(files)
                            selectedFiles.removeAll()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Bin Selected (\(selectedFiles.count))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.red))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                }
            }
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Type")
                .font(.system(size: 13, weight: .semibold))
            
            // All files option
            Button(action: {
                viewModel.setFileTypeFilter(nil)
            }) {
                HStack {
                    Image(systemName: viewModel.selectedFileTypeFilter == nil ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.selectedFileTypeFilter == nil ? .blue : .secondary)
                    Text("All Files")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(viewModel.totalFilesCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // File type filters
            ForEach(FileType.allCases, id: \.self) { fileType in
                Button(action: {
                    viewModel.setFileTypeFilter(fileType)
                }) {
                    HStack {
                        Image(systemName: fileType.icon)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Image(systemName: viewModel.selectedFileTypeFilter == fileType ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedFileTypeFilter == fileType ? .blue : .secondary)
                        Text(fileType.displayName)
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(viewModel.files.filter { $0.fileType == fileType }.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Group Review View

// SmartAction moved to its own file

struct GroupReviewView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @State private var selectedFiles: Set<UUID> = []
    @State private var hoveredFileId: UUID? = nil
    
    private var groupStats: (totalSize: Int64, dateRange: String?) {
        viewModel.getGroupStats()
    }
    
    private var smartActions: [SmartAction] {
        viewModel.getSmartActions()
    }
    
    private var groupTitle: String {
        guard let suggestion = viewModel.groupReviewSuggestion else {
            return "Review Group"
        }
        
        switch suggestion.type {
        case .duplicate(let count, _):
            return "\(count) Duplicate Files"
        case .similarNames(let pattern, let count, _):
            return "\(count) \(pattern)"
        case .sameSession(let count, _):
            return "\(count) Files from Same Session"
        default:
            return "Review Group"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with context
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        viewModel.showGroupReview = false
                        viewModel.groupReviewFiles = []
                        viewModel.groupReviewSuggestion = nil
                        selectedFiles.removeAll()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(groupTitle)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if let dateRange = groupStats.dateRange {
                            Text(dateRange)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(viewModel.groupReviewFiles.count) files")
                            .font(.system(size: 12, weight: .medium))
                        Text(ByteCountFormatter.string(fromByteCount: groupStats.totalSize, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // Smart Actions (if available)
            if !smartActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(smartActions.enumerated()), id: \.offset) { _, action in
                            SmartActionCard(action: action)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background {
                    VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                }
                
                Divider()
                    .opacity(0.2)
            }
            
            // File grid with larger thumbnails
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(Array(viewModel.groupReviewFiles.enumerated()), id: \.element.id) { index, file in
                        FileGridCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.id),
                            isHovered: hoveredFileId == file.id,
                            isShaking: false,
                            onToggle: {
                                if selectedFiles.contains(file.id) {
                                    selectedFiles.remove(file.id)
                                } else {
                                    selectedFiles.insert(file.id)
                                }
                            },
                            onPreview: {
                                // Preview all files in group, starting with this one
                                let urls = viewModel.groupReviewFiles.map { $0.url }
                                QuickLookHelper.shared.preview(urls: urls, currentIndex: index)
                            },
                            onHover: { hovering in
                                hoveredFileId = hovering ? file.id : nil
                            }
                        )
                    }
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    selectedFiles = Set(viewModel.groupReviewFiles.map { $0.id })
                }) {
                    Text("Select All")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    let filesToBin = viewModel.groupReviewFiles.filter { selectedFiles.contains($0.id) }
                    viewModel.binGroupFiles(filesToBin)
                    selectedFiles.removeAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Bin Selected (\(selectedFiles.count))")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color.red)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedFiles.isEmpty)
                
                Button(action: {
                    let filesToKeep = viewModel.groupReviewFiles.filter { selectedFiles.contains($0.id) }
                    viewModel.keepGroupFiles(filesToKeep)
                    selectedFiles.removeAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Keep Selected (\(selectedFiles.count))")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color.green)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedFiles.isEmpty)
                    }
                    .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
        }
    }
}

// MARK: - Smart Action Card

struct SmartActionCard: View {
    let action: SmartAction
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action.action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(action.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(width: 200)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(isHovered ? 0.15 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// FileGridCard moved to its own file
