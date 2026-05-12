import Foundation

extension Double {
    /// Formats the value as a Euro amount using the German locale.
    ///
    /// Example: `1234.56` → `"€ 1.234,56"`
    var eurFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        formatter.locale = Locale(identifier: "de_DE")
        // German convention uses period as thousands separator and comma as decimal.
        return formatter.string(from: NSNumber(value: self)) ?? "€ 0,00"
    }

    /// Formats the value as a percentage string using the German locale.
    ///
    /// Example: `0.123` → `"12,3 %"` (pass `0.123` for 12.3 %)
    var percentFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "de_DE")
        // The German percent style already appends " %", e.g. "12,3 %".
        return formatter.string(from: NSNumber(value: self)) ?? "0 %"
    }
}
