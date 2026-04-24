import SwiftUI

@main
struct parkfriendsApp: App {
    var body: some Scene {
#if canImport(AppKit)
        WindowGroup {
            ContentView()
                .background(Color.black)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            // Remove "New Window" — one window is all we need
            CommandGroup(replacing: .newItem) {}
        }
#else
        WindowGroup {
            ContentView()
                .background(Color.black)
        }
#endif
    }
}
