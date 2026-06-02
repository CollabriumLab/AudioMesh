import SwiftUI

@main
struct AudioMeshApp: App {
    @StateObject private var manager = AudioMeshManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("AudioMesh", systemImage: "headphones") {
            VStack {
                HStack {
                    Circle()
                        .fill(manager.isActive ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(manager.isActive ? "Synced" : "Inactive")
                        .font(.caption)
                }

                if manager.isActive {
                    Text(manager.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("Show AudioMesh") {
                    for win in NSApplication.shared.windows where win.isVisible {
                        win.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                        return
                    }
                }

                Button("Quit") {
                    manager.cleanup()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
