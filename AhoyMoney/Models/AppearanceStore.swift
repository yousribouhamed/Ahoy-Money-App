import SwiftUI

/// User-selected appearance mode. Persisted between launches.
enum AppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// SwiftUI's `.preferredColorScheme(_:)` value. `nil` means follow system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// App-wide appearance store.
///
/// Drives `.preferredColorScheme(_:)` from the root and persists the user's
/// choice to `UserDefaults` so the next cold start picks up where we left off.
@Observable
final class AppearanceStore {
    private static let key = "ahoy.appearance.mode"

    var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.key)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let stored = AppearanceMode(rawValue: raw) {
            self.mode = stored
        } else {
            self.mode = .dark
        }
    }
}
