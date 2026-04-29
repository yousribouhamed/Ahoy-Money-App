import Foundation

struct WorldCountry: Identifiable, Hashable {
    let code: String   // ISO 3166-1 alpha-2, e.g. "US"
    let name: String   // Localised display name
    let flag: String   // Emoji flag from code

    var id: String { code }
}

enum Countries {
    /// All ISO countries with display name and emoji flag, sorted alphabetically.
    static let all: [WorldCountry] = {
        let locale = Locale.current
        return Locale.Region.isoRegions
            // Leaf regions = independent countries (filters out continents/sub-regions).
            .filter { $0.subRegions.isEmpty }
            .compactMap { region -> WorldCountry? in
                guard let name = locale.localizedString(forRegionCode: region.identifier) else {
                    return nil
                }
                return WorldCountry(
                    code: region.identifier,
                    name: name,
                    flag: flagEmoji(for: region.identifier)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    private static func flagEmoji(for regionCode: String) -> String {
        let base: UInt32 = 127397 // 0x1F1E6 ('🇦') minus 'A'
        return regionCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
