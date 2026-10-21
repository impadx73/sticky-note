import Foundation

/// Screen rectangle stored as plain numbers so the JSON file stays simple.
struct NoteFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// One sticky note. The text is kept as RTFD so fonts, styles and pasted
/// images survive a restart.
struct Note: Codable, Identifiable {
    var id: UUID
    var contentData: Data
    var color: NoteColor
    /// Frame of the note when it is expanded (screen coordinates).
    var frame: NoteFrame
    var isCollapsed: Bool
    var isFloating: Bool
    var isTranslucent: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), contentData: Data = Data(), color: NoteColor = .yellow, frame: CGRect) {
        self.id = id
        self.contentData = contentData
        self.color = color
        self.frame = NoteFrame(frame)
        self.isCollapsed = false
        self.isFloating = false
        self.isTranslucent = false
        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }

    // Tolerant decoding so older/newer note files still load.
    private enum CodingKeys: String, CodingKey {
        case id, contentData, color, frame, isCollapsed, isFloating, isTranslucent, createdAt, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        contentData = try c.decodeIfPresent(Data.self, forKey: .contentData) ?? Data()
        color = try c.decodeIfPresent(NoteColor.self, forKey: .color) ?? .yellow
        frame = try c.decodeIfPresent(NoteFrame.self, forKey: .frame)
            ?? NoteFrame(CGRect(x: 100, y: 100, width: 280, height: 260))
        isCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isFloating = try c.decodeIfPresent(Bool.self, forKey: .isFloating) ?? false
        isTranslucent = try c.decodeIfPresent(Bool.self, forKey: .isTranslucent) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }
}
