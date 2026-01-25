import SwiftUI
import AppKit

@main
struct DesktopDeclutterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Main window that opens automatically - simplified approach
        WindowGroup {
            ContentView()
                .frame(width: 420, height: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 680)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        // Menu bar icon as secondary option
        MenuBarExtra("Declutter", systemImage: "square.stack.3d.up.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force window to appear on main screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
            if let window = NSApplication.shared.windows.first {
                let screen = NSScreen.main ?? NSScreen.screens.first
                if let screen = screen {
                    let screenFrame = screen.visibleFrame
                    let windowWidth: CGFloat = 420
                    let windowHeight: CGFloat = 680
                    let x = screenFrame.midX - windowWidth / 2
                    let y = screenFrame.midY - windowHeight / 2
                    window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
                }
                window.makeKeyAndOrderFront(nil)
                window.level = .floating
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
