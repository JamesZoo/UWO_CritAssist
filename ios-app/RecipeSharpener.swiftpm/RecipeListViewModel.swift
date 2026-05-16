import Foundation
import Observation

@Observable
@MainActor
final class RecipeListViewModel {
    private let store: RecipeStore

    var recipes: [Recipe] = []
    var query: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    init(store: RecipeStore) {
        self.store = store
    }

    var displayed: [Recipe] {
        SearchRanking.rank(recipes, for: query)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recipes = try await store.allRecipes()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func upsert(_ recipe: Recipe) async {
        do {
            try await store.save(recipe)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func delete(_ recipe: Recipe) async {
        do {
            try await store.delete(id: recipe.id)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
