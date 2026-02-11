import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: DeclutterViewModel
    @StateObject private var cloudManager = CloudManager.shared
    
    init(isPresented: Binding<Bool>, viewModel: DeclutterViewModel) {
        self._isPresented = isPresented
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cloudDestinationsSection
                    Divider()
                    generalPreferencesSection
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    private var headerView: some View {
        HStack {
            Text("Settings")
                .font(.headline)
            Spacer()
            Button("Done") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
    }
    
    private var cloudDestinationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud Destinations")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            if cloudManager.destinations.isEmpty {
                Text("No cloud folders connected.")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                ForEach(cloudManager.destinations) { dest in
                    destinationRow(for: dest)
                }
            }
            
            Button(action: addNewDestination) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Destination")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func destinationRow(for dest: CloudDestination) -> some View {
        HStack {
            Image(systemName: dest.provider.iconName)
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.name)
                    .font(.system(size: 14, weight: .medium))
                Text(dest.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if cloudManager.activeDestinationId == dest.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Set Active") {
                    cloudManager.setActive(dest.id)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            
            Button(action: {
                cloudManager.removeDestination(id: dest.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cloudManager.activeDestinationId == dest.id ? Color.blue.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
        )
    }
    
    private var generalPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            Toggle("Trash Immediately", isOn: Binding(
                get: { viewModel.immediateBinning },
                set: { viewModel.immediateBinning = $0 }
            ))
            .toggleStyle(.switch)
            
            Text("Files are moved to trash immediately instead of queued.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider().padding(.vertical, 8)
            
            Button("Change Scan Folder...") {
                viewModel.promptForFolderAndLoad { didSelect in
                    if didSelect {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func addNewDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Connect Cloud Folder"
        panel.message = "Select a local request folder for your cloud provider (e.g. iCloud Drive, Google Drive)"
        panel.level = .floating
        panel.isFloatingPanel = true
        
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let provider = cloudManager.isValidCloudDirectory(url) else {
                let alert = NSAlert()
                alert.messageText = "Choose a cloud folder"
                alert.informativeText = "Only cloud folders (iCloud Drive, Google Drive, or other CloudStorage providers) can be added here."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }

            let canonicalURL = cloudManager.canonicalCloudURL(for: url, provider: provider) ?? url
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: canonicalURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                let alert = NSAlert()
                alert.messageText = "Choose a writable cloud folder"
                alert.informativeText = "Google Drive requires a writable folder like “My Drive”. Please choose a folder you can write to."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }

            let confirm = NSAlert()
            confirm.messageText = "Set up this cloud folder?"
            confirm.informativeText = "DesktopDeclutter will create a “DesktopDeclutter” folder inside this location and move files into it."
            confirm.alertStyle = .informational
            confirm.addButton(withTitle: "Set Up")
            confirm.addButton(withTitle: "Cancel")

            if confirm.runModal() == .alertFirstButtonReturn {
                switch cloudManager.validateDestinationWritable(canonicalURL) {
                case .success:
                    break
                case .failure:
                    let alert = NSAlert()
                    alert.messageText = "This folder isn’t writable"
                    alert.informativeText = "Google Drive requires a writable folder like “My Drive”. Please choose a folder you can write to."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                let name = canonicalURL.lastPathComponent
                cloudManager.addDestination(name: name, url: canonicalURL, provider: provider)
            }
        }
    }
}
