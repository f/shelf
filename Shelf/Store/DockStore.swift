import Foundation
import Combine

@Observable
final class DockStore {
    var docks: [DockConfig] = []
    
    private let fileURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let shelfDir = appSupport.appendingPathComponent("Shelf", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: shelfDir.path) {
            try? FileManager.default.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        }
        
        self.fileURL = shelfDir.appendingPathComponent("docks.json")
        load()
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            docks = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            docks = try JSONDecoder().decode([DockConfig].self, from: data)
        } catch {
            print("Failed to load docks: \(error)")
            docks = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(docks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save docks: \(error)")
        }
    }
    
    func createDock(name: String) -> DockConfig {
        let dock = DockConfig(name: name)
        docks.append(dock)
        save()
        return dock
    }
    
    func deleteDock(id: UUID) {
        docks.removeAll { $0.id == id }
        save()
    }
    
    func addItem(to dockID: UUID, item: DockItem) {
        guard let index = docks.firstIndex(where: { $0.id == dockID }) else { return }
        // Allow multiple spacers/separators/snippets, but deduplicate apps and links
        if item.type == .spacer || item.type == .separator || item.type == .snippet || item.type == .stickyNote {
            docks[index].items.append(item)
            save()
            return
        }
        let isDuplicate = docks[index].items.contains { existing in
            if item.type == .link { return existing.urlString == item.urlString }
            return existing.appPath == item.appPath
        }
        if !isDuplicate {
            docks[index].items.append(item)
            save()
        }
    }
    
    func addLink(to dockID: UUID, url: String, name: String) {
        var item = DockItem.link(url: url, name: name)
        addItem(to: dockID, item: item)
        
        // Fetch favicon in background
        FaviconFetcher.shared.fetch(for: url) { [weak self] faviconPath in
            DispatchQueue.main.async {
                guard let self,
                      let dockIdx = self.docks.firstIndex(where: { $0.id == dockID }),
                      let itemIdx = self.docks[dockIdx].items.firstIndex(where: { $0.id == item.id })
                else { return }
                self.docks[dockIdx].items[itemIdx].faviconPath = faviconPath
                self.save()
            }
        }
    }
    
    func addSpacer(to dockID: UUID) {
        addItem(to: dockID, item: .spacer())
    }
    
    func addSeparator(to dockID: UUID) {
        addItem(to: dockID, item: .separator())
    }
    
    func addSnippet(to dockID: UUID, name: String, content: String) {
        addItem(to: dockID, item: .snippet(name: name, content: content))
    }
    
    func addStickyNote(to dockID: UUID, name: String = "Sticky Note") {
        addItem(to: dockID, item: .stickyNote(name: name))
    }
    
    func updateStickyNoteContent(dockID: UUID, itemID: UUID, content: String) {
        guard let dockIdx = docks.firstIndex(where: { $0.id == dockID }),
              let itemIdx = docks[dockIdx].items.firstIndex(where: { $0.id == itemID })
        else { return }
        docks[dockIdx].items[itemIdx].snippetContent = content
        save()
    }
    
    func moveItem(in dockID: UUID, fromID: UUID, toID: UUID) {
        guard let dockIdx = docks.firstIndex(where: { $0.id == dockID }),
              let fromIdx = docks[dockIdx].items.firstIndex(where: { $0.id == fromID }),
              let toIdx = docks[dockIdx].items.firstIndex(where: { $0.id == toID }),
              fromIdx != toIdx
        else { return }
        let item = docks[dockIdx].items.remove(at: fromIdx)
        docks[dockIdx].items.insert(item, at: toIdx)
        save()
    }
    
    func removeItem(from dockID: UUID, itemID: UUID) {
        guard let index = docks.firstIndex(where: { $0.id == dockID }) else { return }
        docks[index].items.removeAll { $0.id == itemID }
        save()
    }
    
    func updateDockPosition(id: UUID, x: Double, y: Double) {
        guard let index = docks.firstIndex(where: { $0.id == id }) else { return }
        docks[index].positionX = x
        docks[index].positionY = y
        save()
    }
    
    func updateDock(id: UUID, config: DockConfig) {
        guard let index = docks.firstIndex(where: { $0.id == id }) else { return }
        docks[index] = config
        save()
    }
}
