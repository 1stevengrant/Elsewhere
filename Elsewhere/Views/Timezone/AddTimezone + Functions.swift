import AppKit
import CoreLocation
import Foundation
import GRDB
import MapKit
import SwiftUI

extension AddTimezone {
    func searchPlace(_ completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, _ in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                DispatchQueue.main.async {
                    if let placemark = placemarks?.first {
                        if let timeZone = placemark.timeZone {
                            self.selectedTimeZone = timeZone
                        }
                        self.countryEmoji = Utils.shared.getCountryEmoji(for: placemark.isoCountryCode ?? "")
                    }
                }
            }
        }
    }

    func saveEntry() {
        let fileName = UUID().uuidString + ".png"
        let fileURL = getApplicationSupportDirectory().appendingPathComponent(fileName)

        if let tiffData = image?.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
            } catch {
                print("Failed to save image: \(error)")
            }
        }

        do {
            try database.dbWriter.write { db in
                let lastId = try Entry.select(GRDB.max(Entry.Columns.id), as: Int64.self).fetchOne(db) ?? 0
                let entry = Entry(
                    id: lastId + 1,
                    type: !countryEmoji.isEmpty && image == nil ? .place : .person,
                    name: name,
                    city: city,
                    timezoneIdentifier: selectedTimeZone?.identifier ?? "",
                    flag: image == nil ? countryEmoji : "",
                    photoData: image != nil ? fileURL.absoluteString : nil
                )

                try entry.insert(db)
            }
        } catch {
            print("Failed to save entry \(error)")
        }

        router.cleanActiveRoute()
        resetForm()
    }

    private func resetForm() {
        image = nil
        name = ""
        city = ""
        showingXAccountInput = false
        showingTGAccountInput = false
        selectedTimeZone = TimeZone.current
        isShowingPopover = false
        countryEmoji = ""
        selectedTimeZone = nil
    }

    private func getApplicationSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
