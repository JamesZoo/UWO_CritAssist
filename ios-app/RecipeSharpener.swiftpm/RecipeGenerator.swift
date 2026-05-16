import Foundation

struct InitialRecipeDraft: Sendable, Codable, Hashable {
    var name: String
    var summary: String
    var ingredients: [Ingredient]
    var steps: [Step]
    var referenceStyle: String?
}

protocol RecipeGenerator: Sendable {
    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft
}
