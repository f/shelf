import SwiftUI

struct ManagerView: View {
    let store: DockStore
    let windowController: DockWindowController
    
    @State private var newDockName = ""
    @State private var selectedDockID: UUID?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if store.docks.isEmpty {
                emptyState
            } else {
                dockList
            }
            
            Divider()
            footer
        }
        .frame(width: 380, height: 420)
    }
    
    private var header: some View {
        HStack {
            Text("Manage Shelves")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "dock.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No shelves yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Create a shelf and drag items into it")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dockList: some View {
        List(selection: $selectedDockID) {
            ForEach(store.docks) { dock in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dock.name)
                            .font(.body.weight(.medium))
                        Text("\(dock.items.count) item\(dock.items.count == 1 ? "" : "s") · \(dock.orientation.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            toggleOrientation(dock)
                        } label: {
                            Image(systemName: dock.orientation == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(dock.orientation == .horizontal ? "Switch to vertical" : "Switch to horizontal")
                        
                        Button(role: .destructive) {
                            deleteDock(dock)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var footer: some View {
        HStack {
            TextField("New shelf name", text: $newDockName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    createDock()
                }
            
            Button("Create") {
                createDock()
            }
            .disabled(newDockName.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
    }
    
    private func createDock() {
        let name = newDockName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let dock = store.createDock(name: name)
        newDockName = ""
        windowController.showDock(dock)
    }
    
    private func deleteDock(_ dock: DockConfig) {
        windowController.hideDock(dock.id)
        store.deleteDock(id: dock.id)
    }
    
    private func toggleOrientation(_ dock: DockConfig) {
        var updated = dock
        updated.orientation = dock.orientation == .horizontal ? .vertical : .horizontal
        store.updateDock(id: dock.id, config: updated)
        windowController.updateDock(updated)
    }
}
