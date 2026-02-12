import SwiftUI

struct StickyNoteView: View {
    let itemID: UUID
    let dockID: UUID
    @Bindable var store: DockStore
    var onClose: () -> Void = {}
    
    @State private var text: String = ""
    @State private var saveTimer: Timer?
    
    private let maxCharacters = 500
    
    private var item: DockItem? {
        store.docks
            .first(where: { $0.id == dockID })?
            .items.first(where: { $0.id == itemID })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
                
                Text(item?.displayName ?? "Sticky Note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(text.count)/\(maxCharacters)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.3))
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.3))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Text area
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.black.opacity(0.85))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxCharacters {
                        text = String(newValue.prefix(maxCharacters))
                    }
                    scheduleSave()
                }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.7),
                    Color(red: 1.0, green: 0.92, blue: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.black.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .onAppear {
            text = item?.snippetContent ?? ""
        }
    }
    
    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            DispatchQueue.main.async {
                store.updateStickyNoteContent(dockID: dockID, itemID: itemID, content: text)
            }
        }
    }
}
