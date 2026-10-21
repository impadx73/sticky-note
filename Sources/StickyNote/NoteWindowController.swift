import AppKit
import UniformTypeIdentifiers

/// Owns one note window: the text view, colour, float / translucent /
/// collapse state, and saving every change back to the store.
final class NoteWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    static let defaultSize = NSSize(width: 280, height: 260)
    static let minimumWidth: CGFloat = 160
    static let minimumExpandedHeight: CGFloat = NoteBarView.height + 60
    static let translucentAlpha: CGFloat = 0.82
    static let defaultFont: NSFont = NSFont(name: "Helvetica", size: 14) ?? NSFont.systemFont(ofSize: 14)

    private(set) var note: Note
    var onDelete: ((UUID) -> Void)?

    private let store = NoteStore.shared
    private let noteContentView = NoteContentView(frame: .zero)
    private let barView = NoteBarView(frame: .zero)
    private let scrollView: NSScrollView
    private let textView: NSTextView
    private var isAdjustingFrame = false

    // MARK: - Setup

    init(note: Note) {
        self.note = note
        let scroll = NSTextView.scrollableTextView()
        scrollView = scroll
        // scrollableTextView() always installs an NSTextView as its document view.
        textView = (scroll.documentView as? NSTextView) ?? NSTextView(frame: .zero)

        let window = NoteWindow(
            contentRect: note.frame.rect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.delegate = self
        configureWindow(window)
        configureViews()
        loadContent()
        applyColor()
        applyFloating()
        applyTranslucency()
        if note.isCollapsed {
            applyCollapsed(animated: false)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureWindow(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: Self.minimumWidth, height: Self.minimumExpandedHeight)
        window.isMovableByWindowBackground = false
        window.appearance = NSAppearance(named: .aqua)
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.managed, .fullScreenAuxiliary]
        window.animationBehavior = .documentWindow
        window.title = "Note"
        window.contentView = noteContentView
        window.initialFirstResponder = textView
    }

    private func configureViews() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.importsGraphics = true
        textView.usesFontPanel = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.font = Self.defaultFont
        textView.textColor = .black
        textView.insertionPointColor = .black
        textView.typingAttributes = [
            .font: Self.defaultFont,
            .foregroundColor: NSColor.black
        ]
        textView.delegate = self

        barView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        noteContentView.addSubview(barView)
        noteContentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            barView.topAnchor.constraint(equalTo: noteContentView.topAnchor),
            barView.leadingAnchor.constraint(equalTo: noteContentView.leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: noteContentView.trailingAnchor),
            barView.heightAnchor.constraint(equalToConstant: NoteBarView.height),

            scrollView.topAnchor.constraint(equalTo: barView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: noteContentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: noteContentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: noteContentView.bottomAnchor)
        ])

        noteContentView.onHoverChanged = { [weak self] hovering in
            self?.barView.setButtonsVisible(hovering)
        }
        barView.onClose = { [weak self] in
            self?.confirmDelete()
        }
        barView.onToggleCollapse = { [weak self] in
            self?.toggleCollapse(nil)
        }
    }

    private func loadContent() {
        if !note.contentData.isEmpty,
           let attributed = NSAttributedString(rtfd: note.contentData, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = ""
        }
        updateWindowTitle()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(textView)
    }

    // MARK: - Applying state

    private func applyColor() {
        noteContentView.backgroundColor = note.color.background
        barView.fillColor = note.color.barColor
        window?.invalidateShadow()
    }

    private func applyFloating() {
        window?.level = note.isFloating ? .floating : .normal
    }

    private func applyTranslucency() {
        window?.alphaValue = note.isTranslucent ? Self.translucentAlpha : 1.0
    }

    private func applyCollapsed(animated: Bool) {
        guard let window = window else { return }
        isAdjustingFrame = true
        let current = window.frame
        if note.isCollapsed {
            scrollView.isHidden = true
            let height = NoteBarView.height
            let target = NSRect(x: current.minX, y: current.maxY - height, width: current.width, height: height)
            window.minSize = NSSize(width: Self.minimumWidth, height: height)
            window.maxSize = NSSize(width: 100_000, height: height)
            window.setFrame(target, display: true, animate: animated)
        } else {
            let height = max(CGFloat(note.frame.height), Self.minimumExpandedHeight)
            let target = NSRect(x: current.minX, y: current.maxY - height, width: current.width, height: height)
            window.maxSize = NSSize(width: 100_000, height: 100_000)
            window.minSize = NSSize(width: Self.minimumWidth, height: Self.minimumExpandedHeight)
            window.setFrame(target, display: true, animate: animated)
            scrollView.isHidden = false
        }
        isAdjustingFrame = false
        window.invalidateShadow()
    }

    private func updateWindowTitle() {
        let firstLine = textView.string
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        window?.title = firstLine.isEmpty ? "Note" : String(firstLine.prefix(40))
    }

    private func persist() {
        note.modifiedAt = Date()
        store.update(note)
    }

    private func recordFrame() {
        guard !isAdjustingFrame, let window = window else { return }
        let f = window.frame
        if note.isCollapsed {
            let expandedHeight = CGFloat(note.frame.height)
            note.frame = NoteFrame(NSRect(x: f.minX, y: f.maxY - expandedHeight, width: f.width, height: expandedHeight))
        } else {
            note.frame = NoteFrame(f)
        }
        store.update(note)
    }

    var hasContent: Bool {
        guard let storage = textView.textStorage else { return false }
        if storage.containsAttachments(in: NSRange(location: 0, length: storage.length)) {
            return true
        }
        return !storage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions (reached through the responder chain from the menus)

    @objc func setNoteColor(_ sender: NSMenuItem) {
        let all = NoteColor.allCases
        guard all.indices.contains(sender.tag) else { return }
        note.color = all[sender.tag]
        UserDefaults.standard.set(note.color.rawValue, forKey: "defaultNoteColor")
        applyColor()
        persist()
    }

    @objc func toggleFloating(_ sender: Any?) {
        note.isFloating.toggle()
        applyFloating()
        persist()
    }

    @objc func toggleTranslucent(_ sender: Any?) {
        note.isTranslucent.toggle()
        applyTranslucency()
        persist()
    }

    @objc func toggleCollapse(_ sender: Any?) {
        note.isCollapsed.toggle()
        applyCollapsed(animated: true)
        persist()
    }

    @objc func deleteNoteAction(_ sender: Any?) {
        confirmDelete()
    }

    @objc func exportNote(_ sender: Any?) {
        guard let window = window, let storage = textView.textStorage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rtf, .plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let baseName = window.title == "Note" ? "Sticky Note" : window.title
        panel.nameFieldStringValue = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-") + ".rtf"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let range = NSRange(location: 0, length: storage.length)
            do {
                if url.pathExtension.lowercased() == "txt" {
                    try storage.string.write(to: url, atomically: true, encoding: .utf8)
                } else {
                    let data = storage.rtf(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) ?? Data()
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    // MARK: - Deleting

    func confirmDelete() {
        guard let window = window else { return }
        if !hasContent {
            deleteNote()
            return
        }

        window.makeKeyAndOrderFront(nil)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to delete this note?"
        alert.informativeText = "Closing a note deletes it. You can export it first to keep a copy."
        let deleteButton = alert.addButton(withTitle: "Delete")
        let cancelButton = alert.addButton(withTitle: "Cancel")
        let exportButton = alert.addButton(withTitle: "Export…")
        deleteButton.hasDestructiveAction = true
        deleteButton.keyEquivalent = ""
        cancelButton.keyEquivalent = "\r"
        exportButton.keyEquivalent = ""

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            deleteNote()
        case .alertThirdButtonReturn:
            exportNote(nil)
        default:
            break
        }
    }

    private func deleteNote() {
        store.remove(id: note.id)
        let id = note.id
        window?.orderOut(nil)
        window?.close()
        onDelete?(id)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmDelete()
        return false
    }

    func windowDidMove(_ notification: Notification) {
        recordFrame()
    }

    func windowDidResize(_ notification: Notification) {
        recordFrame()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let storage = textView.textStorage else { return }
        let range = NSRange(location: 0, length: storage.length)
        note.contentData = storage.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) ?? Data()
        persist()
        updateWindowTitle()
    }
}

// MARK: - Menu validation (check marks for colour / float / translucent)

extension NoteWindowController: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else { return true }
        switch action {
        case #selector(setNoteColor(_:)):
            let all = NoteColor.allCases
            let isCurrent = all.indices.contains(item.tag) && all[item.tag] == note.color
            item.state = isCurrent ? .on : .off
            return true
        case #selector(toggleFloating(_:)):
            item.state = note.isFloating ? .on : .off
            return true
        case #selector(toggleTranslucent(_:)):
            item.state = note.isTranslucent ? .on : .off
            return true
        case #selector(toggleCollapse(_:)):
            item.title = note.isCollapsed ? "Expand" : "Collapse"
            return true
        default:
            return true
        }
    }
}
