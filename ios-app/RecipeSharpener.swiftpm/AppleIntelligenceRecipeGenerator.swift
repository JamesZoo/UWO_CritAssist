import Foundation

#if canImport(FoundationModels)
import FoundationModels

@Generable
struct GeneratedRecipeContent: Sendable {
    @Guide(description: "Dish name in the same language as the user's input. Preserve CJK characters if given.")
    var name: String

    @Guide(description: "One- to two-sentence description of the dish.")
    var summary: String

    @Guide(description: "Regional or style reference like 'Sichuan home-style' or 'Cantonese'. Empty string if none applies.")
    var referenceStyle: String

    @Guide(description: "Ingredient lines including measurable quantities, e.g. '300 g pork kidney' or '2 tbsp Shaoxing wine'.")
    var ingredients: [String]

    @Guide(description: "Ordered preparation steps as concise imperative sentences.")
    var steps: [String]
}

struct AppleIntelligenceRecipeGenerator: RecipeGenerator {

    private static let dishInstructions = """
    You are an experienced cook. Given a dish name in any language (including Chinese, \
    Japanese, Korean, French, etc.), produce a starter recipe drawn from common public \
    preparations of that dish. Be accurate and culturally appropriate. If the dish has \
    a regional style, note it. Ingredients must include measurable quantities. Steps \
    must be ordered, actionable, and concise. Keep the dish name in the original \
    language as the user wrote it.
    """

    private static let parseInstructions = """
    You parse a user-pasted recipe (possibly in any language, possibly noisy with ads \
    or navigation text) into clean structured form. Extract the dish name, a one-line \
    summary, ingredients with measurable quantities, and ordered preparation steps. \
    Ignore non-recipe content such as ads, newsletters, comments, and navigation. If \
    the user provided an expected-dish description, use it to disambiguate.
    """

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: Self.dishInstructions)
        let response = try await session.respond(
            to: "Create a starter recipe for the dish: \(dishName)",
            generating: GeneratedRecipeContent.self
        )
        return response.content.toDraft(originalName: dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        // URL fetching is handled by WebRecipeExtractor; the AI path runs on the
        // resulting plain text via parseRecipe(fromText:) when the caller decides.
        throw RecipeGeneratorError.unsupportedInput
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: Self.parseInstructions)
        let prompt: String
        if let description, !description.isEmpty {
            prompt = "Expected dish: \(description)\n\nRecipe text:\n\(text)"
        } else {
            prompt = "Recipe text:\n\(text)"
        }
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedRecipeContent.self
        )
        return response.content.toDraft(originalName: description ?? "User recipe")
    }
}

private extension GeneratedRecipeContent {
    func toDraft(originalName: String) -> InitialRecipeDraft {
        InitialRecipeDraft(
            name: name.isEmpty ? originalName : name,
            summary: summary,
            ingredients: ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Ingredient(name: $0, quantity: "") },
            steps: steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { Step(index: $0.offset + 1, text: $0.element) },
            referenceStyle: referenceStyle.isEmpty ? nil : referenceStyle
        )
    }
}

enum AppleIntelligence {
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }
}
#else
enum AppleIntelligence {
    static var isAvailable: Bool { false }
}
#endif
