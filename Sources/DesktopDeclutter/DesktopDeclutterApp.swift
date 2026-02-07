import SwiftUI
import AppKit

@main
struct DesktopDeclutterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var viewModel = DeclutterViewModel()
    
    var body: some Scene {
        // Main window that opens automatically
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 420, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        Settings {
            SettingsView(isPresented: Binding.constant(true), viewModel: viewModel)
        }
        
        // Menu bar icon for quick access
        MenuBarExtra("Declutter", systemImage: "square.stack.3d.up.fill") {
            Button("Show Window") {
                // Show all windows
                for window in NSApplication.shared.windows {
                    window.makeKeyAndOrderFront(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("w", modifiers: .command)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
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
