import AppKit

/// Borderless windows refuse keyboard focus by default; a note must accept it.
final class NoteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Root view of a note: paints the paper colour, rounds the corners and
/// reports mouse hover so the top-bar buttons can fade in and out.
final class NoteContentView: NSView {
    var onHoverChanged: ((Bool) -> Void)?

    var backgroundColor: NSColor = .white {
        didSet { needsDisplay = true }
    }

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}

/// The thin strip along the top of a note. Drag it to move the note,
/// double-click it to collapse / expand. Shows a close box and a collapse
/// box while the mouse is over the note, like Stickies.
final class NoteBarView: NSView {
    static let height: CGFloat = 22

    var onClose: (() -> Void)?
    var onToggleCollapse: (() -> Void)?

    var fillColor: NSColor = .lightGray {
        didSet { needsDisplay = true }
    }

    private let closeButton = NSButton(frame: .zero)
    private let collapseButton = NSButton(frame: .zero)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure(closeButton, symbol: "xmark", fallback: "✕", tooltip: "Delete Note", action: #selector(closeTapped))
        configure(collapseButton, symbol: "minus", fallback: "–", tooltip: "Collapse / Expand", action: #selector(collapseTapped))
        addSubview(closeButton)
        addSubview(collapseButton)
        setButtonsVisible(false)
        positionButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configure(_ button: NSButton, symbol: String, fallback: String, tooltip: String, action: Selector) {
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.toolTip = tooltip
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .heavy)
            button.image = image.withSymbolConfiguration(config) ?? image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.title = fallback
            button.imagePosition = .noImage
        }
        button.contentTintColor = NSColor.black.withAlphaComponent(0.55)
        button.target = self
        button.action = action
    }

    func setButtonsVisible(_ visible: Bool) {
        closeButton.isHidden = !visible
        collapseButton.isHidden = !visible
    }

    private func positionButtons() {
        let size: CGFloat = 16
        let y = (bounds.height - size) / 2
        closeButton.frame = NSRect(x: 5, y: y, width: size, height: size)
        collapseButton.frame = NSRect(x: bounds.width - size - 5, y: y, width: size, height: size)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        positionButtons()
    }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onToggleCollapse?()
        } else {
            window?.performDrag(with: event)
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func collapseTapped() {
        onToggleCollapse?()
    }
}
