import SwiftUI

struct FolderStructureView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Location Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(viewModel.breadcrumbText.isEmpty ? "Root" : viewModel.breadcrumbText)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Back Button (if in subfolder)
            if viewModel.isInSubfolder {
                Button(action: {
                    withAnimation {
                        viewModel.returnToParentFolder()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(viewModel.parentFolderName)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            Text("In this folder")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // File/Folder List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.filteredFiles) { file in
                            HStack(spacing: 8) {
                                Image(nsImage: file.icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                
                                Text(file.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .truncationMode(.middle)
                                    .foregroundColor(file.decision != nil || viewModel.viewedFileIds.contains(file.id) ? .secondary : (file.id == viewModel.currentFile?.id ? .primary : .secondary))
                                    
                                Spacer()
                                
                                // Inline Undo for decided files
                                if file.decision != nil {
                                    Button(action: {
                                        withAnimation { viewModel.undoDecision(for: file) }
                                    }) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .frame(width: 16, height: 16)
                                            .background(Circle().fill(Color.gray.opacity(0.1)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Processed Status Icons
                                if let decision = file.decision {
                                    Image(systemName: decision == .kept ? "checkmark.circle.fill" : (decision == .binned ? "trash.circle.fill" : (decision == .cloud ? "icloud.and.arrow.up.fill" : (decision == .moved ? "folder.fill.badge.arrow.forward" : "square.stack.3d.up.fill"))))
                                        .font(.system(size: 12))
                                        .foregroundColor(decision == .kept ? .green : (decision == .binned ? .red : .blue))
                                }
                                
                                // Indicator for current file
                                if file.id == viewModel.currentFile?.id {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .opacity(file.decision != nil || viewModel.viewedFileIds.contains(file.id) ? 0.6 : 1.0) // Dim processed or viewed files
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(file.id == viewModel.currentFile?.id ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Single tap selects/jumps. Double tap on folder enters.
                                if let index = viewModel.filteredFiles.firstIndex(where: { $0.id == file.id }) {
                                    withAnimation {
                                        viewModel.currentFileIndex = index
                                        viewModel.generateThumbnails(for: index)
                                        viewModel.triggerShake(for: file.id)
                                    }
                                }
                            }
                            .gesture(
                                TapGesture(count: 2).onEnded {
                                    if file.fileType == .folder {
                                        withAnimation {
                                            viewModel.enterFolder(file)
                                        }
                                    }
                                }
                            )
                            .id(file.id)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .id(viewModel.selectedFolderURL) // Force refresh when folder changes
                .onAppear {
                    scrollToCurrent(proxy: proxy)
                }
                .onChange(of: viewModel.currentFile?.id) { _ in
                    scrollToCurrent(proxy: proxy)
                }
            }
            // Footer: Gallery Toggle
            VStack(spacing: 8) {
                Divider()
                Button(action: {
                    withAnimation {
                        viewModel.isGridMode.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isGridMode ? "square.grid.2x2.fill" : "square.grid.2x2")
                        Text(viewModel.isGridMode ? "Back to Swipe View" : "Switch to Gallery")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
    
    private func scrollToCurrent(proxy: ScrollViewProxy) {
        if let currentId = viewModel.currentFile?.id {
            withAnimation {
                proxy.scrollTo(currentId, anchor: .center)
            }
        }
    }
}
