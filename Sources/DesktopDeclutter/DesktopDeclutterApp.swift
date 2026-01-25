import SwiftUI

@main
struct DesktopDeclutterApp: App {
    var body: some Scene {
        MenuBarExtra("Declutter", systemImage: "square.stack.3d.up.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window) // Allows for a full SwiftUI view in a popover
    }
}
