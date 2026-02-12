import AppKit
import SwiftUI

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class StickyNoteWindowController {
    private var windows: [UUID: NSPanel] = [:]
    private let store: DockStore
    
    init(store: DockStore) {
        self.store = store
    }
    
    func toggleNote(itemID: UUID, dockID: UUID) {
        if let existing = windows[itemID] {
            existing.orderOut(nil)
            windows[itemID] = nil
            return
        }
        showNote(itemID: itemID, dockID: dockID)
    }
    
    func showNote(itemID: UUID, dockID: UUID) {
        if let existing = windows[itemID] {
            existing.orderFront(nil)
            return
        }
        
        let noteView = StickyNoteView(
            itemID: itemID,
            dockID: dockID,
            store: store,
            onClose: { [weak self] in
                self?.closeNote(itemID: itemID)
            }
        )
        
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 200),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(rootView: noteView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView
        
        // Position near center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 130
            let y = screenFrame.midY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        windows[itemID] = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    func closeNote(itemID: UUID) {
        windows[itemID]?.orderOut(nil)
        windows[itemID] = nil
    }
    
    func closeAll() {
        for (_, panel) in windows {
            panel.orderOut(nil)
        }
        windows.removeAll()
    }
    
    func isNoteOpen(itemID: UUID) -> Bool {
        windows[itemID] != nil
    }
}
