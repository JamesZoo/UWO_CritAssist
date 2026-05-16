import Foundation

struct DefaultRecipeGenerator: RecipeGenerator {
    let fallback: RecipeGenerator
    let webExtractor: WebRecipeExtractor

    init(fallback: RecipeGenerator, webExtractor: WebRecipeExtractor = WebRecipeExtractor()) {
        self.fallback = fallback
        self.webExtractor = webExtractor
    }

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        try await fallback.generateInitialRecipe(dishName: dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try await webExtractor.extract(from: url, expectedDish: description)
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try await fallback.parseRecipe(fromText: text, expectedDish: description)
    }
}
