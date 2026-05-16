import Foundation
import Observation

@Observable
@MainActor
final class VariationsViewModel {
    private let brancher: VariationBrancher
    private let clock: Clock

    var recipe: Recipe
    var directive: String = ""
    var isBranching: Bool = false
    var errorMessage: String?

    init(brancher: VariationBrancher, recipe: Recipe, clock: Clock = SystemClock()) {
        self.brancher = brancher
        self.recipe = recipe
        self.clock = clock
    }

    var canBranch: Bool {
        !isBranching && !directive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func branch() async -> Recipe? {
        guard let base = recipe.currentRevision else {
            errorMessage = "Recipe has no base revision to branch from."
            return nil
        }
        let trimmed = directive.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        isBranching = true
        defer { isBranching = false }

        do {
            let draft = try await brancher.branch(from: base, directive: trimmed)
            let firstRev = Revision(
                index: 1,
                createdAt: clock.now,
                ingredients: draft.ingredients,
                steps: draft.steps,
                referenceStyle: draft.referenceStyle,
                rationale: draft.rationale,
                changes: draft.changes,
                addressedFeedbackIDs: []
            )
            let variation = Variation(
                name: draft.name.isEmpty ? trimmed : draft.name,
                directive: trimmed,
                createdAt: clock.now,
                revisions: [firstRev],
                feedback: []
            )
            recipe.variations.append(variation)
            directive = ""
            return recipe
        } catch {
            errorMessage = String(describing: error)
            return nil
        }
    }
}
