import Foundation

protocol RecipeStore: Sendable {
    func allRecipes() async throws -> [Recipe]
    func recipe(id: UUID) async throws -> Recipe?
    func save(_ recipe: Recipe) async throws
    func delete(id: UUID) async throws
    func wipeAll() async throws
}
