import Foundation

extension Date {
    // MARK: - Shared formatter cache

    private static let deDE = Locale(identifier: "de_DE")

    private static func formatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = deDE
        f.dateFormat = format
        return f
    }

    // MARK: - Public API

    /// Full German date string.
    ///
    /// Example: `"12. Mai 2026"`
    var germanDateString: String {
        Date.formatter(format: "dd. MMMM yyyy").string(from: self)
    }

    /// Short German date string.
    ///
    /// Example: `"12.05.2026"`
    var germanShortDate: String {
        Date.formatter(format: "dd.MM.yyyy").string(from: self)
    }

    /// Month and year in German.
    ///
    /// Example: `"Mai 2026"`
    var monthYearString: String {
        Date.formatter(format: "MMMM yyyy").string(from: self)
    }
}
