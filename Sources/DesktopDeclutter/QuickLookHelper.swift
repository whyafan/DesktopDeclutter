import AppKit
import QuickLookUI

class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()
    
    private var urls: [URL] = []
    private var currentIndex: Int = 0
    
    func preview(urls: [URL], currentIndex: Int = 0) {
        self.urls = urls
        self.currentIndex = currentIndex
        
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.currentPreviewItemIndex = currentIndex
            panel.makeKeyAndOrderFront(nil)
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
}
