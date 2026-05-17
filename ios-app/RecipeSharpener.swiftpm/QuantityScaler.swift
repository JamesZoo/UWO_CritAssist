import Foundation

/// Scales a cooking ingredient quantity string by a multiplier.
///
/// Handles: plain integers ("500"), decimals ("1.5"), ASCII fractions ("1/2"),
/// mixed numbers ("1 1/2"), and Unicode fractions (½ ¼ ¾ ⅓ ⅔ ⅛ ⅜ ⅝ ⅞).
/// Non-numeric tokens ("to taste", "a pinch", "as needed") are returned
/// unchanged. Units are preserved verbatim.
///
/// Examples (factor 2):  "500g" → "1 kg" ... actually "1000 g"
/// Wait, we don't convert units. Examples:
///   "500 g" × 2  → "1000 g"
///   "1/2 cup" × 3 → "1 1/2 cups"   (caller preserves the rest)
///   "to taste" × 3 → "to taste"
struct QuantityScaler {

    static func scale(_ quantity: String, by factor: Double) -> String {
        guard abs(factor - 1.0) > 0.001, !quantity.isEmpty else { return quantity }
        let s = expandUnicodeFractions(quantity.trimmingCharacters(in: .whitespaces))
        guard let (value, suffix) = parseLeadingNumber(s), value > 0 else { return quantity }
        let formatted = formatValue(value * factor)
        let unit = suffix.trimmingCharacters(in: .whitespaces)
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
    }

    // MARK: - Private

    private static func expandUnicodeFractions(_ s: String) -> String {
        var r = s
        for (u, a) in [("½","1/2"),("¼","1/4"),("¾","3/4"),("⅓","1/3"),
                       ("⅔","2/3"),("⅛","1/8"),("⅜","3/8"),("⅝","5/8"),("⅞","7/8")] {
            r = r.replacingOccurrences(of: u, with: a)
        }
        return r
    }

    /// Returns the leading numeric value and the remaining suffix, or nil when
    /// no leading number is found. Handles integer, decimal, fraction (N/D),
    /// and mixed number (W N/D) forms.
    private static func parseLeadingNumber(_ s: String) -> (Double, String)? {
        var i = s.startIndex
        var intPart = ""
        while i < s.endIndex, s[i].isNumber {
            intPart.append(s[i])
            i = s.index(after: i)
        }
        guard !intPart.isEmpty else { return nil }
        guard i < s.endIndex else { return Double(intPart).map { ($0, "") } }

        switch s[i] {
        case "/":
            i = s.index(after: i)
            var den = ""
            while i < s.endIndex, s[i].isNumber { den.append(s[i]); i = s.index(after: i) }
            guard let n = Double(intPart), let d = Double(den), d > 0 else { return nil }
            return (n / d, String(s[i...]))

        case ".", ",":
            i = s.index(after: i)
            var dec = ""
            while i < s.endIndex, s[i].isNumber { dec.append(s[i]); i = s.index(after: i) }
            guard let v = Double(dec.isEmpty ? intPart : "\(intPart).\(dec)") else { return nil }
            return (v, String(s[i...]))

        case " ", "\t":
            // Peek for mixed number: "1 1/2"
            let savedI = i
            i = s.index(after: i)
            var num = ""
            while i < s.endIndex, s[i].isNumber { num.append(s[i]); i = s.index(after: i) }
            if !num.isEmpty, i < s.endIndex, s[i] == "/" {
                i = s.index(after: i)
                var den = ""
                while i < s.endIndex, s[i].isNumber { den.append(s[i]); i = s.index(after: i) }
                if let w = Double(intPart), let n = Double(num), let d = Double(den), d > 0 {
                    return (w + n / d, String(s[i...]))
                }
            }
            i = savedI
            return Double(intPart).map { ($0, String(s[i...])) }

        default:
            return Double(intPart).map { ($0, String(s[i...])) }
        }
    }

    /// Format a scaled value as a cooking-friendly string.
    /// Prefers whole numbers, then common cooking fractions (1/8 – 7/8),
    /// then a one-decimal-place fallback.
    private static func formatValue(_ v: Double) -> String {
        guard v > 0 else { return "0" }
        let whole = Int(v)
        let frac = v - Double(whole)

        if frac < 0.04 { return "\(whole)" }
        if frac > 0.96 { return "\(whole + 1)" }

        let knownFracs: [(Double, String)] = [
            (0.125, "1/8"), (0.25, "1/4"), (1.0/3, "1/3"),
            (0.375, "3/8"), (0.5, "1/2"), (0.625, "5/8"),
            (2.0/3, "2/3"), (0.75, "3/4"), (0.875, "7/8")
        ]
        for (f, fs) in knownFracs {
            if abs(frac - f) < 0.04 { return whole == 0 ? fs : "\(whole) \(fs)" }
        }

        let rounded = (v * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }
}
