# Sticky Note

A small, native macOS sticky-notes app written in Swift / AppKit – the look and
feel of Apple's **Stickies**, built from a plain Swift Package with no Xcode
project required.

Ứng dụng ghi chú dán (sticky note) cho macOS, viết bằng Swift/AppKit, giao diện
và cách dùng giống ứng dụng **Stickies** của Apple.

## Features / Tính năng

- Each note is its own window with no title bar – just a thin coloured strip
  to drag it around. Double‑click the strip to collapse the note to one line.
- Six paper colours (Yellow, Blue, Green, Pink, Purple, Gray) – `⌘1`…`⌘6`.
- Rich text: bold / italic / underline, fonts, sizes, pasted images, links,
  spell checking, find & replace (`⌘F`).
- **Float on Top** (`⇧⌘F`) and **Translucent** (`⇧⌘T`) per note.
- Import `.txt` / `.rtf` files as notes, export a note as RTF or plain text.
- Notes, positions, colours and window states are saved automatically to
  `~/Library/Application Support/Sticky Note/notes.json` and restored on launch.
- Closing a note (`⌘W`) deletes it – you are asked first and can export a copy.
- Universal binary (Apple Silicon + Intel), macOS 12 Monterey or newer.

## Install / Cài đặt

1. Download `StickyNote-<version>.dmg` from the
   [Releases](https://github.com/impadx73/sticky-note/releases) page.
2. Open the DMG and drag **Sticky Note** into **Applications**.
3. The app is signed ad‑hoc (not notarised with Apple), so the first launch is
   blocked by Gatekeeper. Either:
   - **macOS 15 Sequoia and later:** open the app once, dismiss the warning,
     then go to *System Settings ▸ Privacy & Security* and click **Open Anyway**;
     or
   - run this in Terminal and then open the app normally:

     ```bash
     xattr -cr "/Applications/Sticky Note.app"
     ```

   Tải file `.dmg` ở mục Releases, kéo app vào thư mục Applications. Vì app
   chưa được notarize với Apple, lần mở đầu tiên macOS sẽ chặn: vào
   *System Settings ▸ Privacy & Security ▸ Open Anyway*, hoặc chạy lệnh
   `xattr -cr "/Applications/Sticky Note.app"` trong Terminal rồi mở lại.

## Keyboard shortcuts / Phím tắt

| Action | Shortcut |
| --- | --- |
| New note | `⌘N` |
| Close (delete) note | `⌘W` |
| Collapse / Expand | `⌘M` or double‑click the top strip |
| Float on Top | `⇧⌘F` |
| Translucent | `⇧⌘T` |
| Colour Yellow … Gray | `⌘1` … `⌘6` |
| Bold / Italic / Underline | `⌘B` / `⌘I` / `⌘U` |
| Bigger / Smaller text | `⌘+` / `⌘-` |
| Show Fonts | `⌘T` |
| Find | `⌘F` |

## Build from source / Tự build

Requires macOS 12+ with Xcode (or the Command Line Tools).

```bash
git clone https://github.com/impadx73/sticky-note.git
cd sticky-note
./scripts/build.sh      # → dist/Sticky Note.app (universal, ad-hoc signed)
./scripts/make-dmg.sh   # → dist/StickyNote-<version>.dmg
```

For a quick debug run without the bundle:

```bash
swift run StickyNote
```

### Continuous integration

`.github/workflows/build.yml` builds the app on a macOS runner on every push
to `main`, uploads the DMG as a workflow artifact, and attaches it to a GitHub
Release whenever a tag like `v1.0.0` is pushed:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

## Project layout

```
Package.swift                  Swift Package manifest (executable target)
Sources/StickyNote/
  main.swift                   Entry point
  AppDelegate.swift            Menus, note creation, restoring notes
  NoteWindowController.swift   One note window: text, colour, float, collapse…
  NoteViews.swift              Window subclass, paper view, top strip
  Note.swift / NoteColor.swift Model
  NoteStore.swift              JSON persistence
packaging/Info.plist           Bundle metadata template
packaging/icon-1024.png        App icon source
scripts/build.sh               Build + wrap into .app
scripts/make-dmg.sh            Package into .dmg
```

## License

MIT
