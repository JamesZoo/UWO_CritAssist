import Foundation
import Observation

@Observable
@MainActor
final class FeedbackViewModel {
    struct RefinementOutcome: Sendable {
        var updatedRecipe: Recipe
        var prevRevision: Revision
        var newRevision: Revision
        var newFeedback: Feedback
    }

    private let refiner: RecipeRefiner
    private let clock: Clock

    let recipe: Recipe
    let variationID: UUID?

    var text: String = ""
    var rating: Int? = nil
    var testerNote: String = ""
    var isSubmitting: Bool = false
    var errorMessage: String?
    var result: RefinementOutcome?

    init(refiner: RecipeRefiner, recipe: Recipe, variationID: UUID? = nil, clock: Clock = SystemClock()) {
        self.refiner = refiner
        self.recipe = recipe
        self.variationID = variationID
        self.clock = clock
    }

    var ownerName: String {
        if let vid = variationID, let v = recipe.variations.first(where: { $0.id == vid }) {
            return "\(recipe.name) · \(v.name)"
        }
        return recipe.name
    }

    var currentRevision: Revision? {
        if let vid = variationID {
            return recipe.variations.first(where: { $0.id == vid })?.currentRevision
        }
        return recipe.currentRevision
    }

    private var feedbackHistory: [Feedback] {
        if let vid = variationID, let v = recipe.variations.first(where: { $0.id == vid }) {
            return v.feedback
        }
        return recipe.feedback
    }

    var canSubmit: Bool {
        !isSubmitting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit() async {
        guard let prev = currentRevision else {
            errorMessage = "No current revision to refine."
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let feedback = Feedback(
            text: trimmed,
            rating: rating,
            createdAt: clock.now,
            revisionID: prev.id,
            testerNote: testerNote.isEmpty ? nil : testerNote
        )

        do {
            let draft = try await refiner.refine(
                recipeID: recipe.id,
                recipeName: recipe.name,
                previousRevision: prev,
                newFeedback: [feedback],
                feedbackHistory: feedbackHistory
            )
            let newRevision = Revision(
                index: prev.index + 1,
                createdAt: clock.now,
                ingredients: draft.ingredients,
                steps: draft.steps,
                referenceStyle: draft.referenceStyle,
                rationale: draft.rationale,
                changes: draft.changes,
                addressedFeedbackIDs: draft.addressedFeedbackIDs.isEmpty ? [feedback.id] : draft.addressedFeedbackIDs
            )

            var updated = recipe
            if let vid = variationID, let vIdx = updated.variations.firstIndex(where: { $0.id == vid }) {
                updated.variations[vIdx].revisions.append(newRevision)
                updated.variations[vIdx].feedback.append(feedback)
            } else {
                updated.revisions.append(newRevision)
                updated.feedback.append(feedback)
            }

            result = RefinementOutcome(
                updatedRecipe: updated,
                prevRevision: prev,
                newRevision: newRevision,
                newFeedback: feedback
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
