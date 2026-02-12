import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct FloatingDockView: View {
    let dockID: UUID
    @Bindable var store: DockStore
    
    @State private var hoveredItemID: UUID?
    @State private var isHoveringDock = false
    @State private var isDragTargeted = false
    @State private var draggingItemID: UUID?
    @State private var showingAddLink = false
    @State private var linkURL = ""
    @State private var linkName = ""
    @State private var showingAddSnippet = false
    @State private var snippetName = ""
    @State private var snippetContent = ""
    
    private var dock: DockConfig? {
        store.docks.first { $0.id == dockID }
    }
    
    var body: some View {
        Group {
            if let dock {
                if dock.orientation == .horizontal {
                    horizontalDock(dock)
                } else {
                    verticalDock(dock)
                }
            }
        }
        .contextMenu {
            Button("Add Link...") {
                linkURL = ""
                linkName = ""
                showingAddLink = true
            }
            Button("Add Snippet...") {
                snippetName = ""
                snippetContent = ""
                showingAddSnippet = true
            }
            Button("Paste Clipboard as Snippet") {
                if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                    let name = String(text.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addSnippet(to: dockID, name: name.isEmpty ? "Snippet" : name, content: text)
                }
            }
            Divider()
            Button("Add Spacer") {
                store.addSpacer(to: dockID)
            }
            Button("Add Separator") {
                store.addSeparator(to: dockID)
            }
        }
        .popover(isPresented: $showingAddLink) {
            addLinkPopover
        }
        .popover(isPresented: $showingAddSnippet) {
            addSnippetPopover
        }
    }
    
    private var addLinkPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Link")
                .font(.headline)
            
            TextField("URL (e.g. https://github.com)", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            
            TextField("Name", text: $linkName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    showingAddLink = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    addLink()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
    
    private var addSnippetPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Snippet")
                .font(.headline)
            
            TextField("Name (e.g. Email Signature)", text: $snippetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            
            TextEditor(text: $snippetContent)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 280, height: 100)
                .border(Color.secondary.opacity(0.3))
            
            HStack {
                Button("Paste from Clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        snippetContent = text
                    }
                }
                .controlSize(.small)
                
                Spacer()
                
                Button("Cancel") {
                    showingAddSnippet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    addSnippet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(snippetContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
    
    private func addSnippet() {
        let content = snippetContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        let name = snippetName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(content.prefix(30))
            : snippetName.trimmingCharacters(in: .whitespaces)
        store.addSnippet(to: dockID, name: name, content: content)
        showingAddSnippet = false
    }
    
    private func addLink() {
        var url = linkURL.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        let name = linkName.trimmingCharacters(in: .whitespaces).isEmpty
            ? (URL(string: url)?.host ?? url)
            : linkName.trimmingCharacters(in: .whitespaces)
        
        store.addLink(to: dockID, url: url, name: name)
        showingAddLink = false
    }
    
    private func horizontalDock(_ dock: DockConfig) -> some View {
        HStack(spacing: 4) {
            if dock.items.isEmpty {
                emptyState
            } else {
                ForEach(dock.items) { item in
                    DockItemView(
                        item: item,
                        iconSize: dock.iconSize,
                        isHovered: hoveredItemID == item.id,
                        proximityScale: 1.0,
                        orientation: dock.orientation,
                        onRemove: { store.removeItem(from: dock.id, itemID: item.id) }
                    )
                    .zIndex(hoveredItemID == item.id ? 10 : 0)
                    .onHover { hovering in
                        hoveredItemID = hovering ? item.id : nil
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background { dockBackground }
        .onHover { hovering in
            isHoveringDock = hovering
            if !hovering {
                hoveredItemID = nil
            }
        }
    }
    
    private func verticalDock(_ dock: DockConfig) -> some View {
        VStack(spacing: 4) {
            if dock.items.isEmpty {
                emptyState
            } else {
                ForEach(dock.items) { item in
                    DockItemView(
                        item: item,
                        iconSize: dock.iconSize,
                        isHovered: hoveredItemID == item.id,
                        proximityScale: 1.0,
                        orientation: dock.orientation,
                        onRemove: { store.removeItem(from: dock.id, itemID: item.id) }
                    )
                    .zIndex(hoveredItemID == item.id ? 10 : 0)
                    .onHover { hovering in
                        hoveredItemID = hovering ? item.id : nil
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background { dockBackground }
        .onHover { hovering in
            isHoveringDock = hovering
            if !hovering {
                hoveredItemID = nil
            }
        }
    }
    
    private var dockBackground: some View {
        ZStack {
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow
            )
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        .overlay {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.blue.opacity(0.6), lineWidth: 2)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Drop items here")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 60)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let targetDockID = dockID
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
                if let error {
                    print("Drop error: \(error)")
                    return
                }
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    print("Drop: could not parse URL from data")
                    return
                }
                
                print("Dropped URL: \(url.path)")
                if let item = DockItem.fromURL(url) {
                    DispatchQueue.main.async {
                        store.addItem(to: targetDockID, item: item)
                    }
                }
            }
        }
        return true
    }
}
