import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = NoteStore.shared
    private var controllers: [UUID: NoteWindowController] = [:]
    private var openOrder: [UUID] = []

    private static let welcomeText = """
    Welcome to Sticky Note!

    • ⌘N makes a new note
    • ⌘1 – ⌘6 change the paper colour
    • Drag the top edge to move a note; double-click it to collapse
    • Window ▸ Float on Top keeps a note above other windows
    • Closing a note (⌘W) deletes it – export first if you want a copy

    Everything is saved automatically.
    """

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        restoreNotes()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if controllers.isEmpty {
            newNote(nil)
        } else if !flag {
            for id in openOrder {
                controllers[id]?.showWindow(nil)
            }
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(newNote(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: - Notes

    private func restoreNotes() {
        if store.notes.isEmpty {
            createNote(with: NSAttributedString(string: Self.welcomeText, attributes: Self.defaultAttributes))
            return
        }
        for saved in store.notes {
            var note = saved
            note.frame = NoteFrame(sanitizedFrame(saved.frame.rect))
            open(note: note)
        }
        if let last = openOrder.last, let controller = controllers[last] {
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func newNote(_ sender: Any?) {
        createNote(with: nil)
    }

    @objc func importText(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .rtf, .rtfd, .text]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose text or RTF files. Each file becomes a new note."
        panel.begin { [weak self] response in
            guard let self = self, response == .OK else { return }
            for url in panel.urls {
                do {
                    let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
                    self.createNote(with: attributed)
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }

    @objc func openGitHubPage(_ sender: Any?) {
        if let url = URL(string: "https://github.com/impadx73/sticky-note") {
            NSWorkspace.shared.open(url)
        }
    }

    private static var defaultAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NoteWindowController.defaultFont,
            .foregroundColor: NSColor.black
        ]
    }

    @discardableResult
    private func createNote(with content: NSAttributedString?) -> NoteWindowController {
        let savedColor = UserDefaults.standard.string(forKey: "defaultNoteColor").flatMap(NoteColor.init(rawValue:)) ?? .yellow
        var note = Note(color: savedColor, frame: nextFrame(size: NoteWindowController.defaultSize))
        if let content = content, content.length > 0 {
            let range = NSRange(location: 0, length: content.length)
            note.contentData = content.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) ?? Data()
        }
        store.add(note)
        let controller = open(note: note)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return controller
    }

    @discardableResult
    private func open(note: Note) -> NoteWindowController {
        let controller = NoteWindowController(note: note)
        controller.onDelete = { [weak self] id in
            self?.controllers[id] = nil
            self?.openOrder.removeAll { $0 == id }
        }
        controllers[note.id] = controller
        openOrder.append(note.id)
        controller.showWindow(nil)
        return controller
    }

    /// Cascades new notes down-right from the key note, wrapping back to the
    /// top-left of the screen when they would run off the edge.
    private func nextFrame(size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let topLeftOrigin = NSPoint(x: visible.minX + 80, y: visible.maxY - 80 - size.height)

        var reference: NSWindow?
        if let key = NSApp.keyWindow, key is NoteWindow {
            reference = key
        } else if let last = openOrder.last {
            reference = controllers[last]?.window
        }

        var origin = topLeftOrigin
        if let ref = reference {
            origin = NSPoint(x: ref.frame.minX + 26, y: ref.frame.maxY - 26 - size.height)
        }
        if origin.x + size.width > visible.maxX || origin.y < visible.minY {
            origin = topLeftOrigin
        }
        return NSRect(origin: origin, size: size)
    }

    /// Keeps a restored note on a screen that still exists.
    private func sanitizedFrame(_ rect: NSRect) -> NSRect {
        let onSomeScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(rect)
        }
        if onSomeScreen {
            return rect
        }
        var fixed = nextFrame(size: rect.size)
        fixed.size = rect.size
        return fixed
    }

    // MARK: - Menu bar

    private func buildMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Sticky Note", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Sticky Note", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Sticky Note", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, to: mainMenu)

        // File
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Note", action: #selector(newNote(_:)), keyEquivalent: "n")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Import Text…", action: #selector(importText(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Export Text…", action: #selector(NoteWindowController.exportNote(_:)), keyEquivalent: "")
        fileMenu.addItem(.separator())
        // performClose: beeps on borderless windows, so route ⌘W to the controller.
        fileMenu.addItem(withTitle: "Close", action: #selector(NoteWindowController.deleteNoteAction(_:)), keyEquivalent: "w")
        addSubmenu(fileMenu, to: mainMenu)

        // Edit
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let pastePlain = editMenu.addItem(withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
        pastePlain.keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())

        let findMenu = NSMenu(title: "Find")
        let findItems: [(String, NSTextFinder.Action, String, NSEvent.ModifierFlags)] = [
            ("Find…", .showFindInterface, "f", [.command]),
            ("Find and Replace…", .showReplaceInterface, "f", [.command, .option]),
            ("Find Next", .nextMatch, "g", [.command]),
            ("Find Previous", .previousMatch, "g", [.command, .shift]),
            ("Use Selection for Find", .setSearchString, "e", [.command])
        ]
        for (title, action, key, modifiers) in findItems {
            let item = findMenu.addItem(withTitle: title, action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = action.rawValue
        }
        let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        findItem.submenu = findMenu
        editMenu.addItem(findItem)

        let spellingMenu = NSMenu(title: "Spelling and Grammar")
        spellingMenu.addItem(withTitle: "Show Spelling and Grammar", action: #selector(NSText.showGuessPanel(_:)), keyEquivalent: ":")
        spellingMenu.addItem(withTitle: "Check Document Now", action: #selector(NSText.checkSpelling(_:)), keyEquivalent: ";")
        spellingMenu.addItem(.separator())
        spellingMenu.addItem(withTitle: "Check Spelling While Typing", action: #selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent: "")
        spellingMenu.addItem(withTitle: "Check Grammar With Spelling", action: #selector(NSTextView.toggleGrammarChecking(_:)), keyEquivalent: "")
        let spellingItem = NSMenuItem(title: "Spelling and Grammar", action: nil, keyEquivalent: "")
        spellingItem.submenu = spellingMenu
        editMenu.addItem(spellingItem)
        addSubmenu(editMenu, to: mainMenu)

        // Font (standard AppKit font menu: Bold, Italic, Underline, Bigger, Smaller, Show Fonts…)
        if let fontMenu = NSFontManager.shared.fontMenu(true) {
            fontMenu.title = "Font"
            addSubmenu(fontMenu, to: mainMenu)
        }

        // Color
        let colorMenu = NSMenu(title: "Color")
        for (index, color) in NoteColor.allCases.enumerated() {
            let item = colorMenu.addItem(withTitle: color.title, action: #selector(NoteWindowController.setNoteColor(_:)), keyEquivalent: "\(index + 1)")
            item.tag = index
            item.image = color.swatchImage
        }
        addSubmenu(colorMenu, to: mainMenu)

        // Window
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Collapse", action: #selector(NoteWindowController.toggleCollapse(_:)), keyEquivalent: "m")
        let floating = windowMenu.addItem(withTitle: "Float on Top", action: #selector(NoteWindowController.toggleFloating(_:)), keyEquivalent: "f")
        floating.keyEquivalentModifierMask = [.command, .shift]
        let translucent = windowMenu.addItem(withTitle: "Translucent", action: #selector(NoteWindowController.toggleTranslucent(_:)), keyEquivalent: "t")
        translucent.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        addSubmenu(windowMenu, to: mainMenu)
        NSApp.windowsMenu = windowMenu

        // Help
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Sticky Note on GitHub", action: #selector(openGitHubPage(_:)), keyEquivalent: "")
        addSubmenu(helpMenu, to: mainMenu)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    private func addSubmenu(_ menu: NSMenu, to mainMenu: NSMenu) {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        mainMenu.addItem(item)
    }
}
