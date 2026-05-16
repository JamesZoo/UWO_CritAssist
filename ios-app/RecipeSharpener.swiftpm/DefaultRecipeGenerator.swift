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
        let descIsCJK = LanguageHeuristics.containsCJK(desc)
        let summary = extracted.summary
        let ingredients = extracted.ingredients.map(\.name).joined(separator: " ")
        let steps = extracted.steps.map(\.text).joined(separator: " ")
        let extractedSampleText = "\(summary) \(ingredients) \(steps)"
        let extractedIsMostlyCJK = LanguageHeuristics.isMostlyCJK(extractedSampleText)

        if descIsCJK && !extractedIsMostlyCJK {
            return "Chinese"
        }
        if !descIsCJK && extractedIsMostlyCJK {
            return "English"
        }
        return nil
    }
}
