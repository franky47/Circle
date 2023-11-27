import AppKit
import AVFoundation
import SwiftUI

struct CameraView: NSViewRepresentable {
  let cameraName: String

  func makeNSView(context: Context) -> NSView {
    let session = AVCaptureSession()

    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
      mediaType:    .video,
      position:     .unspecified
    )

    let preferredCameraName = UserDefaults.standard.string(
      forKey: "cameraSource"
    )
    let device = discoverySession.devices.first(
      where: { $0.localizedName == preferredCameraName }
    ) ?? discoverySession.devices.first

    guard let cameraDevice = device, let input = try? AVCaptureDeviceInput(
      device: cameraDevice
    ) else {
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

class AppDelegate: NSObject, NSApplicationDelegate {
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
    let contentRect = NSRect(
      x: 0,
      y: 0,
      width: windowSize.width,
      height: windowSize.height
    )
    window = DraggableWindow(
      contentRect: contentRect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = NSColor.clear
    window.hasShadow = true
    window.contentView = NSHostingView(
      rootView: ContentView(cameraName: cameraName)
    )

    // Restore the window position
    let xDistanceToEdge = UserDefaults.standard.float(forKey: "windowXDistanceToEdge")
    let yDistanceToEdge = UserDefaults.standard.float(forKey: "windowYDistanceToEdge")
    let xEdgeIndex = UserDefaults.standard.integer(forKey: "windowXEdgeIndex")
    let yEdgeIndex = UserDefaults.standard.integer(forKey: "windowYEdgeIndex")

    // Restore the window screen
    let screenUUID = UserDefaults.standard.string(forKey: "windowScreenUUID")
    let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
    let screenPredicate: (NSScreen) -> Bool = { screen in
        screen.deviceDescription[screenNumberKey] as? String == screenUUID
    }
    let screen = NSScreen.screens.first(where: screenPredicate) ?? NSScreen.main!
    let newOriginX = xEdgeIndex == 0 ? screen.frame.minX + CGFloat(xDistanceToEdge) : screen.frame.maxX - CGFloat(xDistanceToEdge)
    let newOriginY = yEdgeIndex == 0 ? screen.frame.minY + CGFloat(yDistanceToEdge) : screen.frame.maxY - CGFloat(yDistanceToEdge)
    let newOrigin = NSPoint(x: newOriginX, y: newOriginY)

    // Move the window to the new location
    window.setFrameOrigin(newOrigin)

    // window.delegate = self
    window.makeKeyAndOrderFront(nil)
    window.level = .floating

    // Make the window's content view layer-backed
    window.contentView?.wantsLayer = true
    updateWindowShape()

    // Create "Camera source" submenu
    let cameraMenu = NSMenu(title: "Camera source")

    // Get available cameras
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
      mediaType: .video,
      position: .unspecified
    )
    for device in discoverySession.devices {
      let menuItem = NSMenuItem(
        title: device.localizedName,
        action: #selector(changeCameraSource(_:)),
        keyEquivalent: ""
      )
      menuItem.target = self
      menuItem.state = device.localizedName == cameraName ? .on : .off
      cameraMenu.addItem(menuItem)
    }

    // Add "Camera source" submenu to app's menu
    let mainMenu = NSApp.mainMenu!
    let cameraMenuItem = NSMenuItem(
      title: "Camera source",
      action: nil,
      keyEquivalent: ""
    )
    cameraMenuItem.submenu = cameraMenu
    mainMenu.addItem(cameraMenuItem)

    // Create "Screen source" submenu
    let screenMenu = NSMenu(title: "Target screen")

    // Get available screens
    for screen in NSScreen.screens {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let screenUUID = screenNumber?.stringValue
        let menuItem = NSMenuItem(title: screen.localizedName, action: #selector(screenSelected(_:)), keyEquivalent: "")
        menuItem.representedObject = screenUUID
        menuItem.state = screenUUID == UserDefaults.standard.string(forKey: "windowScreenUUID") ? .on : .off
        screenMenu.addItem(menuItem)
    }

    // Add "Screen source" submenu to the menu bar
    let menuBarItem = NSMenuItem(title: "Target screen", action: nil, keyEquivalent: "")
    menuBarItem.submenu = screenMenu
    mainMenu.addItem(menuBarItem)

    // Create "Window Radius" submenu
    let radiusMenu = NSMenu(title: "Window Radius")

    // Add menu items for different radius values
    for radius in [0, 5, 10, 25, 100] {
      let menuItem = NSMenuItem(title: "\(radius)%", action: #selector(windowRadiusChanged(_:)), keyEquivalent: "")
      menuItem.representedObject = radius
      menuItem.state = radius == UserDefaults.standard.integer(forKey: "windowRadius") ? .on : .off
      radiusMenu.addItem(menuItem)
    }

    // Add "Window Radius" submenu to the menu bar
    let radiusMenuItem = NSMenuItem(title: "Window Radius", action: nil, keyEquivalent: "")
    radiusMenuItem.submenu = radiusMenu
    mainMenu.addItem(radiusMenuItem)
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
    window.contentView = NSHostingView(
      rootView: ContentView(cameraName: cameraName)
    )
    // Save preference in UserDefaults
    UserDefaults.standard.set(cameraName, forKey: "cameraSource")
  }

  @objc func screenSelected(_ sender: NSMenuItem) {
    let currentScreen = UserDefaults.standard.string(forKey: "windowScreenUUID")
    let selectedScreen = sender.representedObject as? String
    if (currentScreen == selectedScreen) {
        return
    }
    // Update the preference in UserDefaults
    UserDefaults.standard.set(selectedScreen, forKey: "windowScreenUUID")

    // Update the menu item state
    for menuItem in sender.menu?.items ?? [] {
        menuItem.state = menuItem == sender ? .on : .off
    }

    // Display a dialog to prompt the user to restart the app
    let alert = NSAlert()
    alert.messageText = "Restart Required"
    alert.informativeText = "Please restart the app for the changes to take effect."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  @objc func windowRadiusChanged(_ sender: NSMenuItem) {
    // Update the window radius
    let radius = sender.representedObject as! Int
    UserDefaults.standard.set(radius, forKey: "windowRadius")

    // Update the menu item state
    for menuItem in sender.menu?.items ?? [] {
        menuItem.state = menuItem == sender ? .on : .off
    }

    // Update the window shape
    updateWindowShape()
  }

  func updateWindowShape() {
    guard let contentView = window.contentView else { return }

    // Get the window radius
    let radiusPercentage = UserDefaults.standard.integer(forKey: "windowRadius")

    // Calculate the window corner radius
    let cornerRadius = CGFloat(radiusPercentage) / 100.0 * min(contentView.frame.width, contentView.frame.height) / 2.0

    // Set the corner radius
    contentView.layer?.cornerRadius = cornerRadius

    // Update the shadow to match the new shape
    window.invalidateShadow()
  }
}

class DraggableWindow: NSWindow {
  var initialLocation: NSPoint?

  override func mouseDown(with event: NSEvent) {
    self.initialLocation = event.locationInWindow
  }

  override func mouseDragged(with event: NSEvent) {
    var newOrigin = self.frame.origin

    // Get the mouse location in window coordinates.
    let currentLocation = event.locationInWindow

    // Update the origin with the difference between
    // the new mouse location and the old mouse location.
    newOrigin.x += (currentLocation.x - (initialLocation?.x ?? 0))
    newOrigin.y += (currentLocation.y - (initialLocation?.y ?? 0))

    // Move the window to the new location
    self.setFrameOrigin(newOrigin)

    // Compute the x/y distance to the nearest edge of the screen
    guard let screen = self.screen else { return }
    let xDistances = [
        abs(newOrigin.x - screen.frame.minX), // Left
        abs(newOrigin.x - screen.frame.maxX)  // Right
    ]
    let yDistances = [
        abs(newOrigin.y - screen.frame.minY), // Bottom
        abs(newOrigin.y - screen.frame.maxY)  // Top
    ]
    let minXDistance = xDistances.min()!
    let minYDistance = yDistances.min()!
    let xEdgeIndex = xDistances.firstIndex(of: minXDistance)!
    let yEdgeIndex = yDistances.firstIndex(of: minYDistance)!

    // Save the distance to the nearest edge and the edge index
    UserDefaults.standard.set(minXDistance, forKey: "windowXDistanceToEdge")
    UserDefaults.standard.set(minYDistance, forKey: "windowYDistanceToEdge")
    UserDefaults.standard.set(xEdgeIndex, forKey: "windowXEdgeIndex")
    UserDefaults.standard.set(yEdgeIndex, forKey: "windowYEdgeIndex")
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
