import SwiftUI

extension Color {
    /// Initializes a Color from a 6-character hex string, with or without a leading `#`.
    ///
    /// - Parameter hex: A string like `"#4ade80"` or `"4ade80"`.
    ///   Malformed input falls back to `.clear`.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized = String(sanitized.dropFirst())
        }

        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            self = .clear
            return
        }

        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8)  / 255.0
        let b = Double(value  & 0x0000FF)         / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Returns a Color from a 6-character hex string, with or without a leading `#`.
    ///
    /// - Parameter hex: A string like `"#4ade80"` or `"4ade80"`.
    /// - Returns: The parsed Color, or `.clear` if the input is malformed.
    static func fromHex(_ hex: String) -> Color {
        Color(hex: hex)
    }
}
