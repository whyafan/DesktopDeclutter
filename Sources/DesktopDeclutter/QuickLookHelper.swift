import AppKit
import QuickLookUI

class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()
    
    private var urls: [URL] = []
    private var currentIndex: Int = 0
    
    func preview(urls: [URL], currentIndex: Int = 0) {
        self.urls = urls
        self.currentIndex = currentIndex
        
        guard !urls.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Check if we have a window (required for QLPreviewPanel)
            guard NSApp.keyWindow != nil || !NSApp.windows.isEmpty else {
                // Fallback: open Finder if no window
                if urls.count == 1, let url = urls.first {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                return
            }
            
            // Get QLPreviewPanel
            guard let panel = QLPreviewPanel.shared() else {
                // Fallback: open Finder if panel unavailable
                if urls.count == 1, let url = urls.first {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                return
            }
            
            // Set up data source and delegate
            panel.dataSource = self
            panel.delegate = self
            panel.currentPreviewItemIndex = currentIndex
            
            // Make sure the window can handle the preview panel
            // This is crucial for QLPreviewPanel to work
            if panel.isVisible {
                // If already visible, update and refresh
                panel.currentPreviewItemIndex = currentIndex
                panel.reloadData()
            } else {
                // Show the panel
                panel.makeKeyAndOrderFront(nil)
                panel.updateController()
            }
        }
    }
    
    func preview(url: URL) {
        preview(urls: [url], currentIndex: 0)
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return urls.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index < urls.count else { return nil }
        return urls[index] as QLPreviewItem
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard events
        if event.type == .keyDown {
            switch event.keyCode {
            case 53: // ESC key
                panel.close()
                return true
            default:
                return false
            }
        }
        return false
    }
    
    // This method is called to determine if the panel should handle events
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Return a frame to help position the panel
        if let keyWindow = NSApp.keyWindow {
            return keyWindow.frame
        }
        return .zero
    }
    
    // This method is called to determine the transition image
    @objc func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        return nil
    }
}
