import AppKit

/// The six paper colours offered in the Color menu (same set as Apple's Stickies).
enum NoteColor: String, CaseIterable, Codable {
    case yellow, blue, green, pink, purple, gray

    var title: String {
        switch self {
        case .yellow: return "Yellow"
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .pink:   return "Pink"
        case .purple: return "Purple"
        case .gray:   return "Gray"
        }
    }

    /// Paper colour of the note body.
    var background: NSColor {
        switch self {
        case .yellow: return NSColor(srgbRed: 1.00, green: 0.96, blue: 0.62, alpha: 1)
        case .blue:   return NSColor(srgbRed: 0.76, green: 0.89, blue: 1.00, alpha: 1)
        case .green:  return NSColor(srgbRed: 0.80, green: 0.96, blue: 0.76, alpha: 1)
        case .pink:   return NSColor(srgbRed: 1.00, green: 0.82, blue: 0.88, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.89, green: 0.83, blue: 1.00, alpha: 1)
        case .gray:   return NSColor(srgbRed: 0.91, green: 0.91, blue: 0.91, alpha: 1)
        }
    }

    /// Slightly darker strip drawn along the top edge (drag handle).
    var barColor: NSColor {
        background.blended(withFraction: 0.14, of: .black) ?? background
    }

    /// Small rounded swatch shown next to the colour name in the menu.
    var swatchImage: NSImage {
        let size = NSSize(width: 14, height: 14)
        let paper = background
        return NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            paper.setFill()
            path.fill()
            NSColor.black.withAlphaComponent(0.25).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
    }
}
