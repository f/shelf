import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class DockWindowController {
    private var windows: [UUID: NSPanel] = [:]
    private let store: DockStore
    private var observations: [UUID: NSObjectProtocol] = [:]
    
    init(store: DockStore) {
        self.store = store
    }
    
    func showDock(_ dock: DockConfig) {
        if let existing = windows[dock.id] {
            existing.orderFront(nil)
            return
        }
        
        let panel = createPanel(for: dock)
        windows[dock.id] = panel
        
        let hostingView = makeDockHostingView(for: dock, panel: panel)
        
        panel.contentView = hostingView
        panel.setFrameOrigin(NSPoint(x: dock.positionX, y: dock.positionY))
        
        updatePanelSize(panel, for: dock)
        panel.orderFront(nil)
    }
    
    func hideDock(_ dockID: UUID) {
        windows[dockID]?.orderOut(nil)
        windows[dockID] = nil
        if let obs = observations.removeValue(forKey: dockID) {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    func updateDock(_ dock: DockConfig) {
        guard let panel = windows[dock.id] else {
            if dock.isVisible {
                showDock(dock)
            }
            return
        }
        
        let hostingView = makeDockHostingView(for: dock, panel: panel)
        panel.contentView = hostingView
        updatePanelSize(panel, for: dock)
    }
    
    func refreshAllDocks() {
        let currentIDs = Set(windows.keys)
        let configIDs = Set(store.docks.map(\.id))
        
        for id in currentIDs.subtracting(configIDs) {
            hideDock(id)
        }
        
        for dock in store.docks where dock.isVisible {
            updateDock(dock)
        }
    }
    
    func saveAllPositions() {
        for (id, panel) in windows {
            let origin = panel.frame.origin
            store.updateDockPosition(id: id, x: origin.x, y: origin.y)
        }
    }
    
    private func makeDockHostingView(for dock: DockConfig, panel: NSPanel) -> DockHostingView<FloatingDockView> {
        let dockID = dock.id
        let hostingView = DockHostingView(
            rootView: FloatingDockView(dockID: dockID, store: store)
        )
        hostingView.registerForDraggedTypes(DockHostingView<FloatingDockView>.acceptedTypes)
        
        hostingView.onDropFileURLs = { [weak self] urls in
            guard let self else { return }
            for url in urls {
                if let item = DockItem.fromURL(url) {
                    self.store.addItem(to: dockID, item: item)
                }
            }
            if let dock = self.store.docks.first(where: { $0.id == dockID }) {
                self.updatePanelSize(panel, for: dock)
            }
        }
        
        hostingView.onDropWebURL = { [weak self] url in
            guard let self else { return }
            let name = url.host ?? url.absoluteString
            self.store.addLink(to: dockID, url: url.absoluteString, name: name)
            if let dock = self.store.docks.first(where: { $0.id == dockID }) {
                self.updatePanelSize(panel, for: dock)
            }
        }
        
        hostingView.onDropText = { [weak self] text in
            guard let self else { return }
            let name = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
            self.store.addSnippet(to: dockID, name: name.isEmpty ? "Snippet" : name, content: text)
            if let dock = self.store.docks.first(where: { $0.id == dockID }) {
                self.updatePanelSize(panel, for: dock)
            }
        }
        
        return hostingView
    }
    
    private func createPanel(for dock: DockConfig) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: dock.positionX, y: dock.positionY, width: 200, height: 70),
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
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let obs = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            guard let panel = notification.object as? NSPanel else { return }
            let origin = panel.frame.origin
            self?.store.updateDockPosition(id: dock.id, x: origin.x, y: origin.y)
        }
        observations[dock.id] = obs
        
        return panel
    }
    
    func updatePanelSize(_ panel: NSPanel, for dock: DockConfig) {
        let iconSize = dock.iconSize
        let spacing: Double = 4
        let itemCount = max(Double(dock.items.count), 1)
        
        let width: Double
        let height: Double
        
        switch dock.orientation {
        case .horizontal:
            let hPad: Double = 10
            let vPad: Double = 8
            width = (iconSize * itemCount) + (spacing * (itemCount - 1)) + (hPad * 2)
            height = iconSize + (vPad * 2)
        case .vertical:
            let hPad: Double = 8
            let vPad: Double = 10
            width = iconSize + (hPad * 2)
            height = (iconSize * itemCount) + (spacing * (itemCount - 1)) + (vPad * 2)
        }
        
        let origin = panel.frame.origin
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true, animate: true)
    }
}
