import Foundation
import AppKit

struct DockItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var appPath: String
    var displayName: String
    var type: ItemType = .app
    var urlString: String?
    var faviconPath: String?
    var snippetContent: String?
    
    enum ItemType: String, Codable {
        case app
        case folder
        case link
        case snippet
        case spacer
        case separator
    }
    
    var appURL: URL {
        URL(fileURLWithPath: appPath)
    }
    
    var icon: NSImage {
        switch type {
        case .separator, .spacer:
            return NSImage()
        case .snippet:
            let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Snippet")
                ?? NSImage()
            return img
        case .link:
            if let faviconPath, let img = NSImage(contentsOfFile: faviconPath) {
                img.size = NSSize(width: 512, height: 512)
                return img
            }
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Link")
                ?? NSImage()
        case .app, .folder:
            let icon = NSWorkspace.shared.icon(forFile: appPath)
            icon.size = NSSize(width: 512, height: 512)
            return icon
        }
    }
    
    var isRunning: Bool {
        guard type == .app else { return false }
        let bundleURL = URL(fileURLWithPath: appPath)
        guard let bundle = Bundle(url: bundleURL),
              let bundleID = bundle.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
    
    // MARK: - Factory Methods
    
    static func fromURL(_ url: URL) -> DockItem? {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let displayName = FileManager.default.displayName(atPath: path)
        let isApp = path.hasSuffix(".app")
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        
        let type: ItemType = isApp ? .app : (isDir ? .folder : .app)
        return DockItem(appPath: path, displayName: displayName, type: type)
    }
    
    static func link(url: String, name: String) -> DockItem {
        DockItem(appPath: "", displayName: name, type: .link, urlString: url)
    }
    
    static func spacer() -> DockItem {
        DockItem(appPath: "", displayName: "", type: .spacer)
    }
    
    static func separator() -> DockItem {
        DockItem(appPath: "", displayName: "", type: .separator)
    }
    
    static func snippet(name: String, content: String) -> DockItem {
        DockItem(appPath: "", displayName: name, type: .snippet, snippetContent: content)
    }
}
