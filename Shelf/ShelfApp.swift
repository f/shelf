//
//  ShelfApp.swift
//  Shelf
//
//  Created by Fatih Kadir Akın on 12.02.2026.
//

import SwiftUI
import AppKit

final class AppState {
    let store = DockStore()
    lazy var windowController = DockWindowController(store: store)
    lazy var stickyNoteController = StickyNoteWindowController(store: store)
    
    func showAllDocks() {
        windowController.stickyNoteController = stickyNoteController
        for dock in store.docks where dock.isVisible {
            windowController.showDock(dock)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.appState.showAllDocks()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        appState.windowController.saveAllPositions()
    }
}

@main
struct ShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private var store: DockStore { appDelegate.appState.store }
    private var windowController: DockWindowController { appDelegate.appState.windowController }
    
    var body: some Scene {
        MenuBarExtra("Shelf", systemImage: "dock.rectangle") {
            menuContent
        }
        
        Window("Manage Shelves", id: "manager") {
            ManagerView(store: store, windowController: windowController)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
    
    @ViewBuilder
    private var menuContent: some View {
        Button("Manage Shelves...") {
            showManager()
        }
        .keyboardShortcut("m", modifiers: [.command])
        
        Divider()
        
        if store.docks.isEmpty {
            Text("No shelves created yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.docks) { dock in
                Menu(dock.name) {
                    Button(dock.isVisible ? "Hide" : "Show") {
                        toggleDockVisibility(dock)
                    }
                    
                    Button(dock.orientation == .horizontal ? "Make Vertical" : "Make Horizontal") {
                        toggleOrientation(dock)
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        deleteDock(dock)
                    }
                }
            }
        }
        
        Divider()
        
        Button("New Shelf") {
            createQuickDock()
        }
        .keyboardShortcut("n", modifiers: [.command])
        
        Divider()
        
        Button("Quit Shelf") {
            windowController.saveAllPositions()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
    
    @Environment(\.openWindow) private var openWindow
    
    private func showManager() {
        openWindow(id: "manager")
    }
    
    private func createQuickDock() {
        let count = store.docks.count + 1
        let dock = store.createDock(name: "Shelf \(count)")
        windowController.showDock(dock)
    }
    
    private func toggleDockVisibility(_ dock: DockConfig) {
        var updated = dock
        updated.isVisible.toggle()
        store.updateDock(id: dock.id, config: updated)
        if updated.isVisible {
            windowController.showDock(updated)
        } else {
            windowController.hideDock(dock.id)
        }
    }
    
    private func toggleOrientation(_ dock: DockConfig) {
        var updated = dock
        updated.orientation = dock.orientation == .horizontal ? .vertical : .horizontal
        store.updateDock(id: dock.id, config: updated)
        windowController.updateDock(updated)
    }
    
    private func deleteDock(_ dock: DockConfig) {
        windowController.hideDock(dock.id)
        store.deleteDock(id: dock.id)
    }
}
