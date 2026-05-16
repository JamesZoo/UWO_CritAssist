import Foundation

actor InMemoryRecipeStore: RecipeStore {
    private var byID: [UUID: Recipe] = [:]

    init(seed: [Recipe] = []) {
        for r in seed { byID[r.id] = r }
    }

    func allRecipes() async throws -> [Recipe] {
        Array(byID.values).sorted { $0.createdAt > $1.createdAt }
    }

    func recipe(id: UUID) async throws -> Recipe? { byID[id] }

    func save(_ recipe: Recipe) async throws { byID[recipe.id] = recipe }

    func delete(id: UUID) async throws { byID.removeValue(forKey: id) }

    func wipeAll() async throws { byID.removeAll() }
}
