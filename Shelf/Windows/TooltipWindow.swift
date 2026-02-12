import AppKit
import SwiftUI

final class TooltipWindow {
    private var window: NSPanel?
    
    static let shared = TooltipWindow()
    
    enum Orientation {
        case horizontal
        case vertical
    }
    
    func show(text: String, near view: NSView, orientation: Orientation = .horizontal) {
        hide()
        
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.sizeToFit()
        
        let padding: CGFloat = 16
        let height: CGFloat = 24
        let width = label.frame.width + padding
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating + 1
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        let hostingView = NSHostingView(
            rootView: Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                }
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        panel.contentView = hostingView
        
        guard let viewWindow = view.window else { return }
        let viewFrameInWindow = view.convert(view.bounds, to: nil)
        let viewFrameOnScreen = viewWindow.convertToScreen(viewFrameInWindow)
        
        let x: CGFloat
        let y: CGFloat
        
        switch orientation {
        case .horizontal:
            x = viewFrameOnScreen.midX - width / 2
            y = viewFrameOnScreen.maxY + 6
        case .vertical:
            let screenWidth = viewWindow.screen?.frame.width ?? NSScreen.main?.frame.width ?? 1920
            let dockMidX = viewFrameOnScreen.midX
            
            if dockMidX > screenWidth / 2 {
                // Dock is on the right half — show tooltip to the left
                x = viewFrameOnScreen.minX - width - 6
            } else {
                // Dock is on the left half — show tooltip to the right
                x = viewFrameOnScreen.maxX + 6
            }
            y = viewFrameOnScreen.midY - height / 2
        }
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
        
        self.window = panel
    }
    
    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
