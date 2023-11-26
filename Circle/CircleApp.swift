import SwiftUI
import AppKit
import Cocoa

struct CircleView: View {
    var body: some View {
        Circle()
            .fill(Color.blue)
    }
}

class CircleWindow: NSWindow {
    override var contentView: NSView? {
        didSet {
            guard let contentView = contentView else { return }
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = contentView.frame.width / 2
            contentView.layer?.masksToBounds = true
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 480, height: 300)
        window = NSWindow(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
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
            // No window is created here.
        }
    }
}
