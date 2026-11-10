import Foundation
import GRDB
import Testing
@testable import Elsewhere

struct ThereImportTests {
    let thereDirectory: URL

    init() throws {
        thereDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        let databaseDirectory = thereDirectory.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)

        let photo = thereDirectory.appendingPathComponent("PHOTO.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: photo)

        let containerPhotoURL = "file:///Users/someone/Library/Containers/pm.there.There/Data/Library/Application%20Support/PHOTO.png"

        let thereDatabase = try AppDatabase(DatabasePool(path: databaseDirectory.appendingPathComponent("db.sqlite").path))
        try thereDatabase.dbWriter.write { db in
            try Entry(id: 10, type: .place, name: "Portland", city: "Portland, United States", timezoneIdentifier: "America/Los_Angeles", flag: "🇺🇸").insert(db)
            try Entry(id: 11, type: .person, name: "Sam", city: "London, United Kingdom", timezoneIdentifier: "Europe/London", photoData: containerPhotoURL).insert(db)
            try Entry(id: 12, type: .person, name: "Alex", city: "Sydney, Australia", timezoneIdentifier: "Australia/Sydney", photoData: "file:///missing/GONE.png").insert(db)
        }
    }

    @Test func importsEntriesWithNewIdsAndCopiedPhotos() throws {
        let database = AppDatabase.empty()
        try database.dbWriter.write { db in
            try Entry(id: 1, type: .place, name: "Home", city: "Auckland, New Zealand", timezoneIdentifier: "Pacific/Auckland").insert(db)
        }

        let count = try ThereImport.importEntries(from: thereDirectory, into: database)

        let entries = try database.reader.read { db in
            try Entry.order(Entry.Columns.id).fetchAll(db)
        }

        #expect(count == 3)
        #expect(entries.map(\.id) == [1, 2, 3, 4])
        #expect(entries[1].name == "Portland")
        #expect(entries[1].flag == "🇺🇸")
        #expect(entries[2].photoData?.contains("pm.there.There") == false)
        #expect(entries[2].photoData.flatMap(URL.init(string:)).map { FileManager.default.fileExists(atPath: $0.path) } == true)
        #expect(entries[3].photoData == nil)
    }

    @Test func skipsEntriesThatWereAlreadyImported() throws {
        let database = AppDatabase.empty()

        _ = try ThereImport.importEntries(from: thereDirectory, into: database)
        let secondCount = try ThereImport.importEntries(from: thereDirectory, into: database)

        let total = try database.reader.read { db in
            try Entry.fetchCount(db)
        }

        #expect(secondCount == 0)
        #expect(total == 3)
    }

    @Test func failsWhenTheFolderHasNoDatabase() {
        let emptyDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        #expect(throws: ThereImport.ImportError.self) {
            try ThereImport.importEntries(from: emptyDirectory, into: AppDatabase.empty())
        }
    }
}
