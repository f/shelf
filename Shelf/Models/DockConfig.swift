import Foundation

struct DockConfig: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var items: [DockItem] = []
    var positionX: Double = 100
    var positionY: Double = 100
    var orientation: Orientation = .horizontal
    var autoHide: Bool = false
    var iconSize: Double = 48
    var isVisible: Bool = true
    
    enum Orientation: String, Codable, CaseIterable {
        case horizontal
        case vertical
    }
}
