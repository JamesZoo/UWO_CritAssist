import Foundation
import Observation

@Observable
@MainActor
final class FinalAnalysisViewModel {
    private let finalizer: RecipeFinalizer

    let recipe: Recipe
    var analysis: RecipeAnalysis?
    var isRunning: Bool = false
    var errorMessage: String?
    /// Target serving count for the analysis. Initialised from the recipe's
    /// stored servings; user adjusts before running or re-running.
    var targetServings: Int

    init(finalizer: RecipeFinalizer, recipe: Recipe) {
        self.finalizer = finalizer
        self.recipe = recipe
        self.targetServings = recipe.servings ?? 4
    }

    func run() async {
        isRunning = true
        defer { isRunning = false }
        do {
            analysis = try await finalizer.finalize(recipe: recipe, targetServings: targetServings)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
