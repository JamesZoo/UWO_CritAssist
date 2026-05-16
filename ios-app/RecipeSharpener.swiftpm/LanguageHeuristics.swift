import Foundation

/// Shared character-level heuristics for deciding whether a string is
/// primarily CJK (Chinese / Japanese / Korean). Used by the image service
/// (Wikipedia language preference), the recipe generator and refiner
/// (post-generation language enforcement), and the URL extraction
/// translator (deciding when to translate the imported recipe).
///
/// Single source of truth for the CJK Unicode ranges — previously
/// duplicated across three services with slight inconsistencies.
enum LanguageHeuristics {
    /// True if the string contains at least one CJK ideograph, kana, or
    /// Hangul syllable. Used to detect when an input (typically a short
    /// dish name or description) is in a CJK language.
    static func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { isCJKScalar($0.value) }
    }

    /// True if more than 30% of the alphabetic characters are CJK. Used
    /// to classify the predominant language of a longer text body — a
    /// recipe summary, ingredient list, or extracted page content — so
    /// we can decide whether translation is needed.
    static func isMostlyCJK(_ s: String) -> Bool {
        var cjkCount = 0
        var letterCount = 0
        for scalar in s.unicodeScalars {
            if scalar.properties.isAlphabetic || isCJKScalar(scalar.value) {
                letterCount += 1
                if isCJKScalar(scalar.value) { cjkCount += 1 }
            }
        }
        guard letterCount > 0 else { return false }
        return Double(cjkCount) / Double(letterCount) > 0.3
    }

    private static func isCJKScalar(_ v: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(v)        // CJK Unified Ideographs
            || (0x3400...0x4DBF).contains(v) // CJK Extension A
            || (0x3040...0x30FF).contains(v) // Japanese kana
            || (0xAC00...0xD7AF).contains(v) // Hangul syllables
    }
}
