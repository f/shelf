import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class DockHostingView<Content: View>: NSHostingView<Content> {
    var onDropFileURLs: (([URL]) -> Void)?
    var onDropWebURL: ((URL) -> Void)?
    var onDropText: ((String) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    
    static var acceptedTypes: [NSPasteboard.PasteboardType] {
        [
            .fileURL, .URL, .string, .html, .rtf,
            .init("public.utf8-plain-text"),
            .init("public.html"),
            .init("public.rtf"),
            .init("public.plain-text"),
        ]
    }
    
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        let types = pb.types ?? []
        print("[Shelf] draggingEntered — pasteboard types: \(types.map(\.rawValue))")
        
        onDragEntered?()
        return .copy
    }
    
    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragExited?()
    }
    
    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        var handled = false
        
        let types = pb.types ?? []
        print("[Shelf] performDragOperation — pasteboard types: \(types.map(\.rawValue))")
        
        // 1. File URLs from Finder (.app, folders, files)
        let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] ?? []
        
        if !fileURLs.isEmpty {
            print("[Shelf] Handling as file URLs: \(fileURLs)")
            onDropFileURLs?(fileURLs)
            handled = true
        } else {
            // 2. Try to get text from pasteboard (multiple methods for browser compatibility)
            let text = textFromPasteboard(pb)
            
            if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("[Shelf] Got text (\(trimmed.count) chars): \(String(trimmed.prefix(80)))...")
                
                if looksLikeURL(trimmed) {
                    let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                    if let url = URL(string: urlString) {
                        print("[Shelf] Text looks like URL, handling as web URL")
                        onDropWebURL?(url)
                    } else {
                        onDropText?(text)
                    }
                } else {
                    print("[Shelf] Handling as snippet text")
                    onDropText?(text)
                }
                handled = true
            } else {
                // 3. Web URL only (dragged link with no text)
                let webURLs = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
                if let url = webURLs.first, url.scheme == "http" || url.scheme == "https" {
                    print("[Shelf] Handling as web URL: \(url)")
                    onDropWebURL?(url)
                    handled = true
                }
            }
        }
        
        if !handled {
            print("[Shelf] Drop not handled — no matching content found")
        }
        
        onDragExited?()
        return handled
    }
    
    private func textFromPasteboard(_ pb: NSPasteboard) -> String? {
        // Try multiple pasteboard types for maximum browser compatibility
        if let text = pb.string(forType: .string), !text.isEmpty {
            return text
        }
        if let text = pb.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text")), !text.isEmpty {
            return text
        }
        // Try reading via NSString objects
        if let strings = pb.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let text = strings.first, !text.isEmpty {
            return text
        }
        // HTML fallback — strip tags for plain text
        if let html = pb.string(forType: .html) ?? pb.string(forType: NSPasteboard.PasteboardType("public.html")),
           !html.isEmpty {
            if let data = html.data(using: .utf8),
               let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
                let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !plain.isEmpty { return plain }
            }
        }
        return nil
    }
    
    private func looksLikeURL(_ text: String) -> Bool {
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return true }
        if text.contains(" ") || text.contains("\n") { return false }
        let pattern = #"^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+(/.*)?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
