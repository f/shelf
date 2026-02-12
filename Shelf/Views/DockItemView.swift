import SwiftUI
import AppKit

struct TooltipTracker: NSViewRepresentable {
    let text: String
    let isHovered: Bool
    let orientation: TooltipWindow.Orientation
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isHovered {
            TooltipWindow.shared.show(text: text, near: nsView, orientation: orientation)
        } else {
            TooltipWindow.shared.hide()
        }
    }
}

struct DockItemView: View {
    let item: DockItem
    let iconSize: Double
    let isHovered: Bool
    let proximityScale: Double
    let orientation: DockConfig.Orientation
    let onRemove: () -> Void
    var onStickyNoteTap: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    private var magnifyScale: Double {
        isHovered ? 1.4 : proximityScale
    }
    
    private var pressScale: Double {
        isPressed ? 0.85 : 1.0
    }
    
    @State private var showCopiedFeedback = false
    
    @ViewBuilder
    var body: some View {
        switch item.type {
        case .spacer:
            Color.clear
                .frame(width: iconSize / 2, height: iconSize)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Remove from Shelf", role: .destructive) {
                        onRemove()
                    }
                }
        case .separator:
            Group {
                if orientation == .horizontal {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.25))
                        .frame(width: 2, height: iconSize * 0.6)
                        .padding(.horizontal, 2)
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.25))
                        .frame(width: iconSize * 0.6, height: 2)
                        .padding(.vertical, 2)
                }
            }
            .contextMenu {
                Button("Remove from Shelf", role: .destructive) {
                    onRemove()
                }
            }
        case .stickyNote:
            iconView
        case .app, .folder, .link, .snippet:
            iconView
        }
    }
    
    private let maxScale: Double = 1.4
    
    private var needsIconMask: Bool {
        item.type == .link || item.type == .snippet || item.type == .stickyNote
    }
    
    private var iconView: some View {
        Group {
            if needsIconMask {
                maskedIcon
            } else {
                rawIcon
            }
        }
        .scaleEffect((magnifyScale * pressScale) / maxScale, anchor: .center)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: magnifyScale)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressScale)
        .frame(width: iconSize, height: iconSize)
        .background {
            TooltipTracker(text: item.displayName, isHovered: isHovered, orientation: orientation == .horizontal ? .horizontal : .vertical)
        }
        .onTapGesture {
            launch()
        }
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .overlay(alignment: .bottom) {
            if showCopiedFeedback {
                Text("Pasted!")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.green.opacity(0.85)))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contextMenu {
            if item.type == .app {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(item.appPath, inFileViewerRootedAtPath: "")
                }
            }
            if item.type == .link, let urlString = item.urlString {
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(urlString, forType: .string)
                }
            }
            if item.type == .snippet {
                if let content = item.snippetContent {
                    let preview = content.prefix(60) + (content.count > 60 ? "..." : "")
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(content, forType: .string)
                    }
                    Text(String(preview))
                        .font(.caption)
                }
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) {
                onRemove()
            }
        }
    }
    
    private var rawIcon: some View {
        Image(nsImage: item.icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize * maxScale, height: iconSize * maxScale)
    }
    
    private var maskedIcon: some View {
        let size = iconSize * maxScale
        let cornerRadius = size * 0.22
        
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
    }
    
    private func launch() {
        switch item.type {
        case .stickyNote:
            onStickyNoteTap?()
        case .snippet:
            pasteSnippet()
        case .link:
            if let urlString = item.urlString, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .app, .folder:
            NSWorkspace.shared.open(URL(fileURLWithPath: item.appPath))
        default:
            break
        }
        
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                isPressed = false
            }
        }
    }
    
    private func pasteSnippet() {
        guard let content = item.snippetContent else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Simulate Cmd+V to paste into the active app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
        
        withAnimation {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}
