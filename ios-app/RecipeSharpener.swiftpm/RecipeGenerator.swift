import Foundation

struct InitialRecipeDraft: Sendable, Codable, Hashable {
    var name: String
    var summary: String
    var ingredients: [Ingredient]
    var steps: [Step]
    var referenceStyle: String?
    var imageURL: URL?
    var imageAttribution: ImageAttribution?

    init(
        name: String,
        summary: String = "",
        ingredients: [Ingredient] = [],
        steps: [Step] = [],
        referenceStyle: String? = nil,
        imageURL: URL? = nil,
        imageAttribution: ImageAttribution? = nil
    ) {
        self.name = name
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.referenceStyle = referenceStyle
        self.imageURL = imageURL
        self.imageAttribution = imageAttribution
    }
}

enum RecipeGeneratorError: Error, Sendable, Equatable {
    case unknownDish(String)
    case parsingFailed(String)
    case networkUnavailable
    case unsupportedInput
    case safetyDeclined(String)
}

protocol RecipeGenerator: Sendable {
    /// Synthesize a recipe from public-source knowledge given just a dish name.
    /// Throws `.unknownDish` if no recipe can be produced — the caller should
    /// then offer the user the manual paste/URL fallback.
    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft

    /// Ingest a recipe from a web page URL. The optional description tells the
    /// model what kind of dish to expect ("a Sichuan stir-fry") so it can
    /// resolve ambiguity in extraction.
    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft

    /// Ingest a user-pasted recipe (e.g. a family secret recipe). The optional
    /// description provides context the model can use to normalize structure.
    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft
}
