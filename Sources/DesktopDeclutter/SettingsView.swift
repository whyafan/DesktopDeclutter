import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: DeclutterViewModel
    
    @AppStorage("cloudProvider") private var cloudProvider: CloudProvider = .iCloud
    @AppStorage("cloudPath") private var cloudPathString: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Cloud Integration")
                    .font(.headline)
                
                Picker("Provider", selection: $cloudProvider) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: cloudProvider) { _ in
                    // Reset path when provider changes, or try to auto-detect
                    if cloudPathString.isEmpty {
                        autoDetectPath()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Destination Folder:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(cloudPathString.isEmpty ? "Not Selected" : cloudPathString)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(cloudPathString)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    
                    Button("Select Folder...") {
                        selectFolder()
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            Spacer()
            
            Button("Done") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 400, height: 350)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            if cloudPathString.isEmpty {
                autoDetectPath()
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Cloud Folder"
        
        // Bring to front
        NSApp.activate(ignoringOtherApps: true)
        
        if panel.runModal() == .OK, let url = panel.url {
            cloudPathString = url.path
            viewModel.updateCloudSettings()
        }
    }
    
    private func autoDetectPath() {
        // Simple auto-detection logic
        let fileManager = FileManager.default
        var path: String?
        
        switch cloudProvider {
        case .iCloud:
            // Common iCloud Drive path
            if let url = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
               path = url.path
            } else {
                // Fallback attempt for standard path
                let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                let candidates = [
                    libraryPath.appendingPathComponent("Mobile Documents/com~apple~CloudDocs").path
                ]
                path = candidates.first(where: { fileManager.fileExists(atPath: $0) })
            }
            
        case .googleDrive:
            // Common Google Drive paths
            let home = FileManager.default.homeDirectoryForCurrentUser
            let candidates = [
                "/Volumes/GoogleDrive",
                home.appendingPathComponent("Google Drive").path,
                "/Volumes/GoogleDrive-1" // Sometimes numbered
            ]
            path = candidates.first(where: { fileManager.fileExists(atPath: $0) })
            
        case .custom:
            break
        }
        
        if let detected = path {
            cloudPathString = detected
            viewModel.updateCloudSettings()
        }
    }
}

enum CloudProvider: String, CaseIterable, Identifiable {
    case iCloud = "iCloud Drive"
    case googleDrive = "Google Drive"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}
