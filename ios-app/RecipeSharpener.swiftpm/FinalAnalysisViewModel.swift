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

    init(finalizer: RecipeFinalizer, recipe: Recipe) {
        self.finalizer = finalizer
        self.recipe = recipe
    }

    func run() async {
        isRunning = true
        defer { isRunning = false }
        do {
            analysis = try await finalizer.finalize(recipe: recipe)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
