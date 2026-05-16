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
    func refine(
        previousRevision: Revision,
        newFeedback: [Feedback],
        feedbackHistory: [Feedback]
    ) async throws -> RefinedRevisionDraft
}
