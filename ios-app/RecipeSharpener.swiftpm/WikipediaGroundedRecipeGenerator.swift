import Foundation

/// Wraps another `RecipeGenerator` with a Wikipedia article grounding step
/// for the dish-name path. Instead of asking the LLM to generate a recipe
/// from its training data (high cultural-context and translation-drift
/// risk), this generator first tries to fetch the dish's native-language
/// Wikipedia article and asks the LLM to synthesize a structured recipe
/// from that authentic source material.
///
/// Concrete benefit: for `红烧肉`, the Chinese Wikipedia article uses
/// `五花肉` for pork belly. The LLM sees `五花肉` in the source and uses
/// it directly, avoiding the `pork belly → 猪肚` (pork stomach) error
/// the LLM would otherwise make when generating + translating from
/// scratch.
///
/// Path / URL / text modes are passed through to the wrapped generator
/// unchanged — they already have their own grounding from the user-
/// provided source.
struct WikipediaGroundedRecipeGenerator: RecipeGenerator {
    let fetcher: WikipediaArticleFetcher
    let fallback: RecipeGenerator

    init(fetcher: WikipediaArticleFetcher = WikipediaArticleFetcher(), fallback: RecipeGenerator) {
        self.fetcher = fetcher
        self.fallback = fallback
    }

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        if let article = await fetcher.fetchArticle(for: dishName) {
            do {
                let groundingText = """
                Source: Wikipedia article "\(article.title)" (\(article.language).wikipedia.org)

                \(article.extract)
                """
                let draft = try await fallback.parseRecipe(
                    fromText: groundingText,
                    expectedDish: dishName
                )
                // Preserve the user-provided dish name even if the article's
                // title was different (e.g. variant spelling). The parser may
                // also fail to produce a usable draft; in that case fall
                // through to pure-AI generation below.
                guard !draft.steps.isEmpty || !draft.ingredients.isEmpty else {
                    return try await fallback.generateInitialRecipe(dishName: dishName)
                }
                var withName = draft
                if withName.name.isEmpty {
                    withName.name = dishName
                }
                return withName
            } catch {
                // Synthesis from the article failed — fall through to pure
                // AI generation rather than failing the whole request.
            }
        }
        return try await fallback.generateInitialRecipe(dishName: dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try await fallback.parseRecipe(fromURL: url, expectedDish: description)
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try await fallback.parseRecipe(fromText: text, expectedDish: description)
    }
}
