import Foundation

struct RefinedRevisionDraft: Sendable, Codable, Hashable {
    var ingredients: [Ingredient]
    var steps: [Step]
    var referenceStyle: String?
    var rationale: String
    var changes: [Change]
    var addressedFeedbackIDs: [UUID]
}

protocol RecipeRefiner: Sendable {
    /// Refine a recipe given new feedback. The `recipeID` lets implementations
    /// scope their LanguageModelSession per recipe — multiple refine() calls
    /// on the same recipe can share the same session so the model retains
    /// context across the iterative refinement loop; different recipes get
    /// fresh sessions.
    func refine(
        recipeID: UUID,
        previousRevision: Revision,
        newFeedback: [Feedback],
        feedbackHistory: [Feedback]
    ) async throws -> RefinedRevisionDraft

    /// Drop any cached per-recipe session state. Call when the user undoes a
    /// refinement, or when the recipe's identity changes such that prior
    /// session memory is no longer valid.
    func resetContext(for recipeID: UUID) async
}
