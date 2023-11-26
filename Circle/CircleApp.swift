import SwiftUI
import AppKit
import Cocoa

struct CircleView: View {
    var body: some View {
        Circle()
            .fill(Color.blue)
    }
}

// class CircleWindow: NSWindow {
//     override var contentView: NSView? {
//         didSet {
//             guard let contentView = contentView else { return }
//             contentView.wantsLayer = true
//             contentView.layer?.cornerRadius = contentView.frame.width / 2
//             contentView.layer?.masksToBounds = true
//         }
//     }
// }

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 480, height: 300)
        window = DraggableWindow(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
    }
}

class DraggableWindow: NSWindow {
    var initialLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        self.initialLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let screenVisibleFrame = NSScreen.main!.visibleFrame
        let windowFrame = self.frame
        var newOrigin = windowFrame.origin

        // Get the mouse location in window coordinates.
        let currentLocation = event.locationInWindow

        // Update the origin with the difference between the new mouse location and the old mouse location.
        newOrigin.x += (currentLocation.x - initialLocation.x)
        newOrigin.y += (currentLocation.y - initialLocation.y)

        // Don't let window get dragged up under the menu bar
        if ((newOrigin.y + windowFrame.size.height) > (screenVisibleFrame.origin.y + screenVisibleFrame.size.height)) {
            newOrigin.y = screenVisibleFrame.origin.y + (screenVisibleFrame.size.height - windowFrame.size.height);
        }

        // Move the window to the new location
        self.setFrameOrigin(newOrigin)
    }

    override var contentView: NSView? {
        didSet {
            guard let contentView = contentView else { return }
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = contentView.frame.width / 2
            contentView.layer?.masksToBounds = true
        }
    }
}

struct ContentView: View {
    var body: some View {
        CircleView()
            .frame(width: 480, height: 480)
            .background(Color.clear)
            .clipShape(Circle())
    }
}

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(action: {
                    NSApplication.shared.terminate(self)
                }) {
                    Text("Quit MainApp")

                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
