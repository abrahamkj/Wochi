import Foundation

// MARK: - ReceiptParser

enum ReceiptParser {

    // MARK: - Public API

    /// Parses raw OCR text from a German supermarket receipt into a `Receipt` model.
    static func parse(text: String) -> Receipt {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let storeName = detectStore(in: lines)
        let purchaseDate = extractDate(from: lines) ?? Date()
        let totalAmount = extractTotal(from: lines) ?? 0.0
        let items = extractItems(from: lines)

        let receipt = Receipt(
            storeName: storeName,
            purchaseDate: purchaseDate,
            totalAmount: totalAmount
        )
        receipt.items = items
        return receipt
    }

    // MARK: - Store Detection

    private static let knownChains: [String] = [
        "Kaufland", "Lidl", "REWE", "Edeka", "Aldi", "Penny", "Netto"
    ]

    private static func detectStore(in lines: [String]) -> String {
        for line in lines {
            for chain in knownChains {
                if line.localizedCaseInsensitiveContains(chain) {
                    return chain
                }
            }
        }
        return "Unbekannt"
    }

    // MARK: - Date Extraction

    /// Matches dd.MM.yyyy or dd/MM/yyyy
    private static let datePattern = #/(\d{2})[./](\d{2})[./](\d{4})/#

    private static func extractDate(from lines: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")

        for line in lines {
            if let match = line.firstMatch(of: datePattern) {
                let day = String(match.1)
                let month = String(match.2)
                let year = String(match.3)
                let dateString = "\(day).\(month).\(year)"
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }
        return nil
    }

    // MARK: - Total Extraction

    private static let totalKeywords = ["SUMME", "GESAMT", "Total", "Betrag", "TOTAL", "BETRAG"]
    /// German decimal amount: digits, comma separator, two decimals
    private static let germanAmountPattern = #/(\d+),(\d{2})/#

    private static func extractTotal(from lines: [String]) -> Double? {
        for line in lines {
            let isTotal = totalKeywords.contains { line.localizedCaseInsensitiveContains($0) }
            guard isTotal else { continue }
            if let amount = parseGermanAmount(from: line) {
                return amount
            }
        }
        return nil
    }

    // MARK: - Item Extraction

    /// Price at end of line: digits[,.]digits{2} optionally followed by A, B, or €
    private static let itemPricePattern = #/(\d+[,\.]\d{2})\s*[AB€]?\s*$/#

    private static let skipPrefixes = ["MwSt", "MWST", "mwst", "USt", "Steuer", "Bar", "Karte",
                                        "EC-Cash", "SUMME", "GESAMT", "Betrag", "Total",
                                        "Gegeben", "Rückgeld", "Pfand", "Bon"]

    private static func extractItems(from lines: [String]) -> [ReceiptItem] {
        var items: [ReceiptItem] = []

        for line in lines {
            guard !shouldSkipLine(line) else { continue }
            guard let match = line.firstMatch(of: itemPricePattern) else { continue }

            let priceString = String(match.1)
            guard let price = parseGermanAmount(from: priceString) else { continue }

            // Item name is everything before the price match
            let matchRange = match.range
            let namePart = String(line[line.startIndex..<matchRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)

            guard !namePart.isEmpty else { continue }

            let item = ReceiptItem(
                name: namePart,
                quantity: 1,
                unitPrice: price,
                totalPrice: price
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Helpers

    private static func shouldSkipLine(_ line: String) -> Bool {
        for prefix in skipPrefixes {
            if line.localizedCaseInsensitiveContains(prefix) { return true }
        }
        // Skip lines that are purely numeric (store header phone numbers, etc.)
        if line.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) { return true }
        // Skip very short lines
        if line.count < 4 { return true }
        return false
    }

    /// Parses a German decimal string like "47,83" or "47.83" to a Double.
    private static func parseGermanAmount(from text: String) -> Double? {
        // Find the last occurrence of a price-like pattern
        let pattern = #/(\d+)[,\.](\d{2})/#
        guard let match = text.matches(of: pattern).last else { return nil }
        let euros = String(match.1)
        let cents = String(match.2)
        return Double("\(euros).\(cents)")
    }
}
