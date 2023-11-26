import AppKit
import AVFoundation
import SwiftUI

struct CameraView: NSViewRepresentable {
    let cameraName: String

    func makeNSView(context: Context) -> NSView {
        let session = AVCaptureSession()

        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
        guard let device = discoverySession.devices.first(where: { $0.localizedName == cameraName }) else {
            return NSView()
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return NSView()
        }

        session.addInput(input)

        let width = UserDefaults.standard.float(forKey: "windowWidth")
        let height = UserDefaults.standard.float(forKey: "windowHeight")
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(
          x: 0,
          y: 0,
          width: CGFloat(width),
          height: CGFloat(height)
        )
        previewLayer.videoGravity = .resizeAspectFill

        let view = NSView(frame: previewLayer.frame)
        view.layer = previewLayer

        session.startRunning()

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class AppDelegate: NSObject, NSApplicationDelegate /*, NSWindowDelegate*/ {
    var window: NSWindow!
    var cameraName: String = "Elgato Facecam" // Default camera
    var windowSize: NSSize {
        didSet {
            UserDefaults.standard.set(windowSize.width, forKey: "windowWidth")
            UserDefaults.standard.set(windowSize.height, forKey: "windowHeight")
        }
    }

    override init() {
        // Initialize UserDefaults
        if UserDefaults.standard.object(forKey: "windowWidth") == nil {
            UserDefaults.standard.set(200.0, forKey: "windowWidth")
        }
        if UserDefaults.standard.object(forKey: "windowHeight") == nil {
            UserDefaults.standard.set(200.0, forKey: "windowHeight")
        }

        let width = UserDefaults.standard.float(forKey: "windowWidth")
        let height = UserDefaults.standard.float(forKey: "windowHeight")
        windowSize = NSSize(width: CGFloat(width), height: CGFloat(height))

        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        window = DraggableWindow(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.center()
        window.contentView = NSHostingView(rootView: ContentView(cameraName: cameraName))
        // window.delegate = self
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        // Create "Camera source" submenu
        let cameraMenu = NSMenu(title: "Camera source")

        // Get available cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
        for device in discoverySession.devices {
            let menuItem = NSMenuItem(title: device.localizedName, action: #selector(changeCameraSource(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = device.localizedName == cameraName ? .on : .off
            cameraMenu.addItem(menuItem)
        }

        // Add "Camera source" submenu to app's menu
        let mainMenu = NSApp.mainMenu!
        let cameraMenuItem = NSMenuItem(title: "Camera source", action: nil, keyEquivalent: "")
        cameraMenuItem.submenu = cameraMenu
        mainMenu.addItem(cameraMenuItem)
    }

    @objc func changeCameraSource(_ sender: NSMenuItem) {
        // Uncheck all items
        for item in sender.menu!.items {
            item.state = .off
        }

        // Check selected item
        sender.state = .on

        // Change camera source
        cameraName = sender.title
        window.contentView = NSHostingView(rootView: ContentView(cameraName: cameraName))
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
        newOrigin.x += (currentLocation.x - (initialLocation?.x ?? 0))
        newOrigin.y += (currentLocation.y - (initialLocation?.y ?? 0))

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
    var cameraName: String

    var body: some View {
        let width = CGFloat(UserDefaults.standard.float(forKey: "windowWidth"))
        let height = CGFloat(UserDefaults.standard.float(forKey: "windowHeight"))

        CameraView(cameraName: cameraName)
            .frame(width: width, height: height)
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
