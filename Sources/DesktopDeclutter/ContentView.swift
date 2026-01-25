import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DeclutterViewModel()
    
    @State private var showSettings = false
    @State private var showStackedFiles = false
    @State private var showFilters = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Toolbar with Material Effect
            HStack(spacing: 12) {
                // Undo button (only visible when undo is available)
                if viewModel.canUndo {
                    Button(action: {
                        _ = viewModel.undoLastAction()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle()
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Undo last action (⌘Z)")
                }
                
                // Settings button
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    SettingsView(viewModel: viewModel)
                        .frame(width: 200)
                        .padding(12)
                }
                
                Spacer()
                
                // Progress Bar (Center)
                VStack(spacing: 4) {
                    ProgressView(value: Double(viewModel.currentFileIndex), total: Double(max(viewModel.filteredFiles.count, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 180)
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentFileIndex)")
                            .font(.system(size: 11, weight: .semibold))
                        Text("of")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                        Text("\(viewModel.filteredFiles.count)")
                            .font(.system(size: 11, weight: .semibold))
                        if viewModel.selectedFileTypeFilter != nil {
                            Text("(\(viewModel.totalFilesCount) total)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Filter button
                Button(action: {
                    showFilters.toggle()
                }) {
                    Image(systemName: viewModel.selectedFileTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(viewModel.selectedFileTypeFilter != nil ? .blue : .secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilters, arrowEdge: .top) {
                    FilterView(viewModel: viewModel)
                        .frame(width: 200)
                        .padding(12)
                }
                
                // Stacked files button
                if viewModel.stackedFiles.count > 0 {
                    Button(action: {
                        showStackedFiles.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("\(viewModel.stackedFiles.count)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showStackedFiles, arrowEdge: .top) {
                        StackedFilesView(viewModel: viewModel)
                            .frame(width: 350, height: 500)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                // Material blur effect (unified toolbar)
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            ZStack {
                // Material background for main content
                VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                
                if let error = viewModel.errorMessage {
                     VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Access Issue")
                            .font(.headline)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .font(.callout)
                        
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        Button("Retry") {
                            viewModel.loadFiles()
                        }
                    }
                    .padding()
                } else if !viewModel.isFinished {
                    ZStack {
                    VStack {
                        Spacer()
                        
                        if let file = viewModel.currentFile {
                            CardView(
                                file: file,
                                onKeep: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    viewModel.keepCurrentFile()
                                        }
                                },
                                onBin: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    viewModel.binCurrentFile()
                                        }
                                    },
                                    onPreview: {
                                        QuickLookHelper.shared.preview(url: file.url)
                                }
                            )
                            .id(file.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                            
                            Spacer()
                        }
                        
                        // Floating Action Buttons (overlaying bottom corners)
                        if viewModel.currentFile != nil {
                            HStack {
                                // Bin button (left)
                                FloatingActionButton(
                                    icon: "xmark.circle.fill",
                                    shortcut: "←",
                                    color: Color(red: 1.0, green: 0.27, blue: 0.23), // System red
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.binCurrentFile()
                                        }
                                    }
                                )
                        
                        Spacer()
                        
                                // Stack button (center)
                                FloatingActionButton(
                                    icon: "square.stack.fill",
                                    shortcut: "S",
                                    color: Color(red: 0.0, green: 0.48, blue: 1.0), // System blue
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.stackCurrentFile()
                                        }
                                    }
                                )
                                
                                Spacer()
                                
                                // Keep button (right)
                                FloatingActionButton(
                                    icon: "checkmark.circle.fill",
                                    shortcut: "→",
                                    color: Color(red: 0.20, green: 0.82, blue: 0.35), // System green
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.keepCurrentFile()
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                        }
                    }
                } else {
                    // Summary / Review State
                    ScrollView {
                        VStack(spacing: 24) {
                        if viewModel.binnedFiles.isEmpty {
                                VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                        .font(.system(size: 64, weight: .light))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    VStack(spacing: 8) {
                            Text("All Clean!")
                                            .font(.system(size: 24, weight: .semibold))
                            Text("No files to bin.")
                                            .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top, 40)
                        } else {
                                VStack(spacing: 20) {
                                    // Header
                                    VStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.red)
                                        
                            Text("Review Bin")
                                            .font(.system(size: 22, weight: .semibold))
                            
                                        HStack(spacing: 6) {
                                Text("Total Size:")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                Text(viewModel.formattedReclaimedSpace)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background {
                                            Capsule()
                                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                        }
                                    }
                                    
                                    // File list
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
                                                .frame(width: 36, height: 36)
                                                .cornerRadius(6)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 6)
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
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                            }
                                        }
                                    }
                                    
                                    // Action button
                                    Button(action: {
                                        viewModel.emptyBin()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Move to Trash")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(Color.red)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help("Permanently delete all binned files")
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Rescan button
                            Button(action: {
                                viewModel.loadFiles()
                            }) {
                                Text("Rescan Desktop")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            // Subtle footer with stats
            if !viewModel.isFinished {
                HStack {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .frame(width: 6, height: 6)
                            Text("Binned: \(viewModel.binnedCount)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.20, green: 0.82, blue: 0.35))
                                .frame(width: 6, height: 6)
                            Text("Kept: \(viewModel.keptCount)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                }
            }
        }
        .frame(width: 420, height: 680)
        .onAppear {
            setupKeyboardShortcuts()
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
            default:
                break
            }
            
            return event
        }
    }
}

// MARK: - Visual Effect View (Material Blur)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            
            Toggle("Trash Immediately", isOn: $viewModel.immediateBinning)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)
            
            Text("When enabled, files are moved to Trash immediately instead of being collected for review.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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

// MARK: - Stacked Files View

struct StackedFilesView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stacked Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.stackedFiles.count) file\(viewModel.stackedFiles.count == 1 ? "" : "s") ready for removal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.emptyStack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Remove All")
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
                    ForEach(viewModel.stackedFiles) { file in
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
                                    viewModel.removeFromStack(file)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.red.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Remove from stack")
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

