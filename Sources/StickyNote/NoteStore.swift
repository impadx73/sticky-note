import Foundation

/// Persists all notes to
/// `~/Library/Application Support/Sticky Note/notes.json`.
/// Saves are debounced so typing does not hammer the disk.
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notes: [Note] = []
    let fileURL: URL
    private var pendingSave: DispatchWorkItem?

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Sticky Note", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("notes.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            NSLog("Sticky Note: could not read notes.json (%@)", error.localizedDescription)
            // Keep a copy of the unreadable file so nothing is lost.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    func note(withID id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func add(_ note: Note) {
        notes.append(note)
        scheduleSave()
    }

    func update(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        scheduleSave()
    }

    func remove(id: UUID) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Sticky Note: failed to save notes (%@)", error.localizedDescription)
        }
    }
}
