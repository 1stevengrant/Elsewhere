import AppKit
import GRDB

/// Imports entries and photos from the original There app.
///
/// Both apps are sandboxed, so There's container can only be read after the
/// user picks its Application Support folder in an open panel.
enum ThereImport {
    enum ImportError: LocalizedError {
        case databaseNotFound

        var errorDescription: String? {
            "No There database was found in the selected folder. Choose the folder named Application Support inside There's container."
        }
    }

    static var thereDataDirectory: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingUTF8: $0.pointee.pw_dir) } ?? NSHomeDirectory()

        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Containers/pm.there.There/Data/Library/Application Support", isDirectory: true)
    }

    @MainActor
    static func run(into database: AppDatabase) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = thereDataDirectory
        panel.message = "Choose There's Application Support folder to import your entries."
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let directory = panel.url else {
            return
        }

        let alert = NSAlert()

        do {
            let count = try importEntries(from: directory, into: database)
            alert.messageText = count == 1 ? "Imported 1 entry" : "Imported \(count) entries"
            alert.informativeText = count == 0 ? "Everything in There is already in Elsewhere." : ""
        } catch {
            alert.alertStyle = .warning
            alert.messageText = "Import failed"
            alert.informativeText = error.localizedDescription
        }

        alert.runModal()
    }

    static func importEntries(from directory: URL, into database: AppDatabase) throws -> Int {
        let thereEntries = try readEntries(from: directory)

        let existingEntries = try database.reader.read { db in
            try Entry.fetchAll(db)
        }

        let newEntries = thereEntries.filter { thereEntry in
            !existingEntries.contains { $0.name == thereEntry.name && $0.timezoneIdentifier == thereEntry.timezoneIdentifier }
        }

        let photos = newEntries.map { copyPhoto($0.photoData, from: directory) }

        try database.dbWriter.write { db in
            var nextId = (try Entry.select(GRDB.max(Entry.Columns.id), as: Int64.self).fetchOne(db) ?? 0) + 1

            for (entry, photo) in zip(newEntries, photos) {
                try Entry(
                    id: nextId,
                    type: entry.type,
                    name: entry.name,
                    city: entry.city,
                    timezoneIdentifier: entry.timezoneIdentifier,
                    flag: entry.flag,
                    photoData: photo
                ).insert(db)

                nextId += 1
            }
        }

        return newEntries.count
    }

    /// Reads from a copy so There's live database is never opened or locked.
    private static func readEntries(from directory: URL) throws -> [Entry] {
        let fileManager = FileManager.default
        let source = directory.appendingPathComponent("Database", isDirectory: true)

        guard fileManager.fileExists(atPath: source.appendingPathComponent("db.sqlite").path) else {
            throw ImportError.databaseNotFound
        }

        let copy = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: copy, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: copy) }

        for name in ["db.sqlite", "db.sqlite-wal"] where fileManager.fileExists(atPath: source.appendingPathComponent(name).path) {
            try fileManager.copyItem(at: source.appendingPathComponent(name), to: copy.appendingPathComponent(name))
        }

        return try DatabaseQueue(path: copy.appendingPathComponent("db.sqlite").path).read { db in
            try Entry.order(Entry.Columns.id).fetchAll(db)
        }
    }

    /// Copies a photo stored in There's container into Elsewhere's, returning the new file URL.
    private static func copyPhoto(_ photoData: String?, from directory: URL) -> String? {
        guard let photoData, let url = URL(string: photoData) else {
            return nil
        }

        guard url.isFileURL else {
            return photoData
        }

        let source = directory.appendingPathComponent(url.lastPathComponent)

        guard FileManager.default.fileExists(atPath: source.path) else {
            return nil
        }

        let destination = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(UUID().uuidString).\(source.pathExtension)")

        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            print("Failed to copy photo \(error)")

            return nil
        }

        return destination.absoluteString
    }
}
