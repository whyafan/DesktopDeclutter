import SwiftUI

private struct FolderPreviewItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
}

struct FolderActionView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @StateObject private var cloudManager = CloudManager.shared
    @State private var folderContents: [FolderPreviewItem] = []
    @State private var childCount: Int = 0
    let folder: DesktopFile

    private var liveFolder: DesktopFile {
        viewModel.files.first(where: { $0.id == folder.id }) ?? folder
    }

    private var isRelocated: Bool {
        viewModel.isRelocated(liveFolder)
    }
    
    private var relocatedDestinationPath: String? {
        viewModel.relocationDestination(for: folder)?.path
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Folder Icon & Info
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(nsImage: folder.icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                }
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Text(folder.name)
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)

                    if isRelocated {
                        Text(folder.decision == .cloud ? "Moved to Cloud" : "Moved")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        if let relocatedDestinationPath {
                            Text(relocatedDestinationPath)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        } else {
                            Text("This item has been moved from the current folder.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                    } else {
                        Text("\(childCount) items inside")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preview list of first few items
                if !folderContents.isEmpty && !isRelocated {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(folderContents) { item in
                            HStack {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(item.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                        }
                        if childCount > folderContents.count {
                            Text("+ \(childCount - folderContents.count) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .frame(maxWidth: 320)
                }
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button(action: {
                    withAnimation {
                        viewModel.enterFolder(liveFolder)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                        Text("Dive into Folder")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isRelocated)
                .opacity(isRelocated ? 0.35 : 1.0)
                
                HStack(spacing: 20) {
                    Button("Keep/Skip") {
                        withAnimation {
                            viewModel.skipFolder(liveFolder)
                        }
                    }
                    .buttonStyle(StandardButtonStyle())
                    .disabled(isRelocated)
                    .opacity(isRelocated ? 0.35 : 1.0)

                    if !cloudManager.destinations.isEmpty {
                        if cloudManager.destinations.count > 1 {
                            Menu {
                                ForEach(cloudManager.destinations) { dest in
                                    Button(cloudManager.destinationDisplayName(dest)) {
                                        withAnimation { viewModel.moveToCloud(liveFolder, destination: dest) }
                                    }
                                }
                            } label: {
                                Text("Cloud")
                            }
                            .buttonStyle(StandardButtonStyle())
                            .disabled(isRelocated)
                            .opacity(isRelocated ? 0.35 : 1.0)
                        } else {
                            Button("Cloud") {
                                withAnimation { viewModel.moveToCloud(liveFolder) }
                            }
                            .buttonStyle(StandardButtonStyle())
                            .disabled(isRelocated)
                            .opacity(isRelocated ? 0.35 : 1.0)
                        }
                    }

                    Button("Move") {
                        viewModel.promptForMoveDestination(files: [liveFolder])
                    }
                    .buttonStyle(StandardButtonStyle())
                    .disabled(isRelocated)
                    .opacity(isRelocated ? 0.35 : 1.0)
                    
                    Button("Bin") {
                        withAnimation {
                            viewModel.binCurrentFile()
                        }
                    }
                    .buttonStyle(StandardButtonStyle(isDestructive: true))
                    .disabled(isRelocated)
                    .opacity(isRelocated ? 0.35 : 1.0)
                }

                if isRelocated {
                    Button("Undo") {
                        withAnimation {
                            viewModel.undoDecision(for: liveFolder)
                        }
                    }
                    .buttonStyle(StandardButtonStyle())
                }
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .onAppear {
            loadFolderPreview(url: liveFolder.url)
        }
        .onChange(of: folder.id) { _ in
            loadFolderPreview(url: liveFolder.url)
        }
        .onChange(of: viewModel.actionHistory.count) { _ in
            if !isRelocated {
                loadFolderPreview(url: liveFolder.url)
            }
        }
    }
    
    private func loadFolderPreview(url: URL) {
        let requestedURL = url
        DispatchQueue.main.async {
            self.childCount = 0
            self.folderContents = []
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let keys: [URLResourceKey] = [.isDirectoryKey]
                let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
                let sortedItems = items.prefix(5).map { item -> FolderPreviewItem in
                    let isDirectory = (try? item.resourceValues(forKeys: Set(keys)).isDirectory) ?? false
                    return FolderPreviewItem(name: item.lastPathComponent, isDirectory: isDirectory)
                }
                
                DispatchQueue.main.async {
                    guard self.folder.url == requestedURL else { return }
                    self.childCount = items.count
                    self.folderContents = Array(sortedItems)
                }
            } catch {
                print("Error scanning folder preview: \(error)")
                DispatchQueue.main.async {
                    guard self.folder.url == requestedURL else { return }
                    self.childCount = 0
                    self.folderContents = []
                }
            }
        }
    }
}

struct StandardButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
