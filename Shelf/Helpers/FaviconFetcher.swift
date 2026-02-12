import Foundation
import AppKit

final class FaviconFetcher {
    static let shared = FaviconFetcher()
    
    private let cacheDir: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("Shelf/favicons", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
    
    func cachedPath(for urlString: String) -> String? {
        let filename = safeFilename(for: urlString)
        let path = cacheDir.appendingPathComponent(filename).path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
    
    func fetch(for urlString: String, completion: @escaping (String?) -> Void) {
        if let cached = cachedPath(for: urlString) {
            completion(cached)
            return
        }
        
        guard let url = URL(string: urlString),
              let host = url.host else {
            completion(nil)
            return
        }
        
        // Try Google's favicon service first (high quality), then fallback to /favicon.ico
        let googleURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")!
        
        fetchImage(from: googleURL) { [weak self] image in
            if let image {
                let path = self?.saveImage(image, for: urlString)
                completion(path)
            } else {
                // Fallback: try direct /favicon.ico
                let directURL = URL(string: "https://\(host)/favicon.ico")!
                self?.fetchImage(from: directURL) { [weak self] image in
                    if let image {
                        let path = self?.saveImage(image, for: urlString)
                        completion(path)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    private func fetchImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data),
                  image.isValid else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }
    
    private func saveImage(_ image: NSImage, for urlString: String) -> String? {
        let filename = safeFilename(for: urlString)
        let path = cacheDir.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: path, options: .atomic)
            return path.path
        } catch {
            print("Failed to save favicon: \(error)")
            return nil
        }
    }
    
    private func safeFilename(for urlString: String) -> String {
        let safe = urlString
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .prefix(80)
        return "\(safe).png"
    }
}
