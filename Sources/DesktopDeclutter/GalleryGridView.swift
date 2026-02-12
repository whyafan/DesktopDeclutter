import SwiftUI
import AppKit

struct GalleryGridView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @StateObject private var cloudManager = CloudManager.shared
    @State private var selectedFiles: Set<UUID> = []
    @State private var hoveredFileId: UUID? = nil

    private func promptToConfigureCloud() {
        let alert = NSAlert()
        alert.messageText = "Cloud destination not set up"
        alert.informativeText = "Would you like to open Settings and connect a cloud folder now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gallery View")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.filteredFiles.count) items in current folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Select All / Deselect All
                Button(action: {
                    if selectedFiles.count == viewModel.filteredFiles.count {
                        selectedFiles.removeAll()
                    } else {
                        selectedFiles = Set(viewModel.filteredFiles.map { $0.id })
                    }
                }) {
                    Text(selectedFiles.count == viewModel.filteredFiles.count && !viewModel.filteredFiles.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.filteredFiles.isEmpty)
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider().opacity(0.2)
            
            // File grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.filteredFiles) { file in
                            FileGridCard(
                                file: file,
                                isSelected: selectedFiles.contains(file.id),
                                isHovered: hoveredFileId == file.id,
                                isShaking: viewModel.shakingFileId == file.id,
                                onToggle: {
                                    if selectedFiles.contains(file.id) {
                                        selectedFiles.remove(file.id)
                                    } else {
                                        selectedFiles.insert(file.id)
                                    }
                                    viewModel.stopShake() // Stop shaking on interaction
                                },
                                onPreview: {
                                    QuickLookHelper.shared.preview(url: file.url)
                                },
                                onHover: { hovering in
                                    hoveredFileId = hovering ? file.id : nil
                                }
                            )
                            .id(file.id) // Important for scrolling
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentFile?.id) { _ in
                    if let file = viewModel.currentFile {
                        withAnimation {
                            proxy.scrollTo(file.id, anchor: .center)
                        }
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { _ in
                viewModel.stopShake()
            })
            
            // Footer Actions
            if !selectedFiles.isEmpty {
                VStack(spacing: 0) {
                    Divider().opacity(0.2)
                    HStack(spacing: 16) {
                        Button(action: {
                            // Logic to be added to VM: keepBulk(ids)
                            let filesToKeep = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.keepGroupFiles(filesToKeep) // Using existing group method
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

                        if cloudManager.destinations.count > 1 {
                            Menu {
                                ForEach(cloudManager.destinations) { dest in
                                    Button(cloudManager.destinationDisplayName(dest)) {
                                        let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) }
                                        viewModel.moveGroupToCloud(filesToMove, destination: dest)
                                        selectedFiles.removeAll()
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill")
                                    Text("Cloud (\(selectedFiles.count))")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue))
                            }
                            .buttonStyle(.plain)
                        } else if cloudManager.destinations.count == 1 {
                            Button(action: {
                                let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) }
                                viewModel.moveGroupToCloud(filesToMove)
                                selectedFiles.removeAll()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill")
                                    Text("Cloud (\(selectedFiles.count))")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                promptToConfigureCloud()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill")
                                    Text("Cloud (\(selectedFiles.count))")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.gray))
                            }
                            .buttonStyle(.plain)
                            .help("Cloud is not configured. Click to open Settings.")
                        }

                        Button(action: {
                            let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.promptForMoveDestination(files: filesToMove)
                            selectedFiles.removeAll()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill.badge.arrow.forward")
                                Text("Move (\(selectedFiles.count))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.teal))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                             // Logic to be added to VM: binBulk(ids)
                            let filesToBin = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.binGroupFiles(filesToBin) // Using existing group method
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
