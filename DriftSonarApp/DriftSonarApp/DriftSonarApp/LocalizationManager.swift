//
//  LocalizationManager.swift
//  DriftSonarApp
//
//  TASK-192 (#228): user-selectable UI language (日本語 / English) with in-app
//  switching that takes effect immediately and survives relaunch.
//
//  Placed in the synchronized root group (alongside SettingsView/ContentView) so it
//  is picked up by the build without manual pbxproj surgery.
//

import Foundation
import ObjectiveC
import SwiftUI

// MARK: - AppLanguage

/// The app's selectable UI language. `.system` follows the device language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    /// The `.lproj` resource code to force, or `nil` to follow the system language.
    var bundleCode: String? {
        switch self {
        case .system: return nil
        case .japanese: return "ja"
        case .english: return "en"
        }
    }

    /// Locale pushed into SwiftUI's environment so dates/numbers format in the chosen
    /// language. `nil` for `.system` — the environment keeps the device locale.
    var locale: Locale? {
        bundleCode.map(Locale.init(identifier:))
    }

    /// Label for the pickers. Native names stay constant across the current UI
    /// language (a user hunting for their language reads it in its own script);
    /// only `.system` is localized.
    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("システムに合わせる", comment: "Follow device language")
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

// MARK: - LocalizationManager

/// Owns the selected language: persists it, applies the bundle override, and exposes
/// the current choice for the UI. A singleton because the language is a process-wide
/// concern (it swaps `Bundle.main`'s string lookups and writes UserDefaults).
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    /// UserDefaults key for the persisted raw value. Absent until the user chooses,
    /// which the install-time picker uses to know whether to ask.
    static let storageKey = "appLanguage"

    private(set) var language: AppLanguage

    /// True once the user has made an explicit choice. Observable (not a UserDefaults
    /// read) so the install-time gate re-renders the moment a language is picked.
    private(set) var hasChosen: Bool

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
        hasChosen = stored != nil
        Bundle.setLanguage(language.bundleCode)
    }

    /// Locale for the environment — the device locale when following the system.
    var locale: Locale {
        language.locale ?? Locale.autoupdatingCurrent
    }

    /// Persist and apply a language choice. Swaps the bundle so already-rendered
    /// `Text` re-resolves in the new language on the next environment update.
    func select(_ language: AppLanguage) {
        self.language = language
        hasChosen = true
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        Bundle.setLanguage(language.bundleCode)
    }
}

// MARK: - Bundle language override

/// Associated-object key holding the forced `.lproj` path on `Bundle.main`.
/// A file-private global is the standard associated-object key pattern (Swift 5 mode).
private var bundleLanguageKey: UInt8 = 0

/// `Bundle` subclass that redirects localized-string lookups to a chosen `.lproj`
/// bundle. Installed on `Bundle.main` via `object_setClass`; it adds no stored
/// properties (the path lives in an associated object) so the memory layout stays
/// compatible with the object it re-classes.
private final class LanguageForcingBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let path = objc_getAssociatedObject(self, &bundleLanguageKey) as? String,
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        // `.system` (no forced path) or a missing `.lproj`: fall back to the normal
        // main-bundle resolution, which follows the device language.
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Force `Bundle.main` to resolve localized strings from `language`'s `.lproj`,
    /// or pass `nil` to follow the system. Idempotent and safe to call on every launch
    /// and every switch.
    static func setLanguage(_ language: String?) {
        object_setClass(Bundle.main, LanguageForcingBundle.self)
        let path = language.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
        objc_setAssociatedObject(Bundle.main, &bundleLanguageKey, path, .OBJC_ASSOCIATION_RETAIN)
    }
}
