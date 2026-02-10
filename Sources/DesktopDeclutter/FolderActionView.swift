import SwiftUI

struct FolderActionView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @StateObject private var cloudManager = CloudManager.shared
    @State private var folderContents: [String] = []
    @State private var childCount: Int = 0
    let folder: DesktopFile
    
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
                    
                    Text("\(childCount) items inside")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                // Preview list of first few items
                if !folderContents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(folderContents, id: \.self) { name in
                            HStack {
                                Image(systemName: "doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(name)
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
                        viewModel.enterFolder(folder)
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
                
                HStack(spacing: 20) {
                    Button("Skip") {
                        withAnimation {
                            viewModel.skipFolder(folder)
                        }
                    }
                    .buttonStyle(StandardButtonStyle())

                    if !cloudManager.destinations.isEmpty {
                        if cloudManager.destinations.count > 1 {
                            Menu {
                                ForEach(cloudManager.destinations) { dest in
                                    Button(cloudManager.destinationDisplayName(dest)) {
                                        withAnimation { viewModel.moveToCloud(folder, destination: dest) }
                                    }
                                }
                            } label: {
                                Text("Cloud")
                            }
                            .buttonStyle(StandardButtonStyle())
                        } else {
                            Button("Cloud") {
                                withAnimation { viewModel.moveToCloud(folder) }
                            }
                            .buttonStyle(StandardButtonStyle())
                        }
                    }

                    Button("Move") {
                        viewModel.promptForMoveDestination(files: [folder])
                    }
                    .buttonStyle(StandardButtonStyle())
                    
                    Button("Bin") {
                        withAnimation {
                            viewModel.binCurrentFile()
                        }
                    }
                    .buttonStyle(StandardButtonStyle(isDestructive: true))
                }
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .onAppear {
            loadFolderPreview(url: folder.url)
        }
        .onChange(of: folder.id) { _ in
            loadFolderPreview(url: folder.url)
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
                let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                let sortedItems = items.prefix(5).map { $0.lastPathComponent }
                
                DispatchQueue.main.async {
                    guard self.folder.url == requestedURL else { return }
                    self.childCount = items.count
                    self.folderContents = Array(sortedItems)
                }
            } catch {
                print("Error scanning folder preview: \(error)")
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
