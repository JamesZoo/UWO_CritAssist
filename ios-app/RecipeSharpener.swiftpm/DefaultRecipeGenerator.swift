import Foundation

struct DefaultRecipeGenerator: RecipeGenerator {
    let fallback: RecipeGenerator
    let webExtractor: WebRecipeExtractor
    let translator: (@Sendable (InitialRecipeDraft, String) async throws -> InitialRecipeDraft)?

    init(
        fallback: RecipeGenerator,
        webExtractor: WebRecipeExtractor = WebRecipeExtractor(),
        translator: (@Sendable (InitialRecipeDraft, String) async throws -> InitialRecipeDraft)? = nil
    ) {
        self.fallback = fallback
        self.webExtractor = webExtractor
        self.translator = translator
    }

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        try await fallback.generateInitialRecipe(dishName: dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        let extracted = try await webExtractor.extract(from: url, expectedDish: description)
        // Translate if the user's description language differs from the
        // extracted content's language, and a translator is available.
        if let translator,
           let target = inferTargetLanguage(extracted: extracted, expectedDish: description) {
            do {
                return try await translator(extracted, target)
            } catch {
                // Translation is best-effort — fall back to original extraction
                // rather than failing the whole import.
                return extracted
            }
        }
        return extracted
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try await fallback.parseRecipe(fromText: text, expectedDish: description)
    }

    private func inferTargetLanguage(extracted: InitialRecipeDraft, expectedDish: String?) -> String? {
        guard let desc = expectedDish?.trimmingCharacters(in: .whitespacesAndNewlines),
              !desc.isEmpty else { return nil }
        let descIsCJK = Self.containsCJK(desc)
        let summary = extracted.summary
        let ingredients = extracted.ingredients.map(\.name).joined(separator: " ")
        let steps = extracted.steps.map(\.text).joined(separator: " ")
        let extractedSampleText = "\(summary) \(ingredients) \(steps)"
        let extractedIsMostlyCJK = Self.isMostlyCJK(extractedSampleText)

        if descIsCJK && !extractedIsMostlyCJK {
            return "Chinese"
        }
        if !descIsCJK && extractedIsMostlyCJK {
            return "English"
        }
        return nil
    }

    private static func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { Self.isCJKScalar($0.value) }
    }

    private static func isMostlyCJK(_ s: String) -> Bool {
        var cjkCount = 0
        var letterCount = 0
        for scalar in s.unicodeScalars {
            if scalar.properties.isAlphabetic || isCJKScalar(scalar.value) {
                letterCount += 1
                if isCJKScalar(scalar.value) {
                    cjkCount += 1
                }
            }
        }
        guard letterCount > 0 else { return false }
        return Double(cjkCount) / Double(letterCount) > 0.3
    }

    private static func isCJKScalar(_ v: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(v)
            || (0x3400...0x4DBF).contains(v)
            || (0x3040...0x30FF).contains(v)
            || (0xAC00...0xD7AF).contains(v)
    }
}
