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
    /// A freshly-generated variation awaiting user approval. Not yet appended
    /// to `recipe.variations` — `apply()` does that. `discard()` clears it.
    var pendingVariation: Variation?

    init(brancher: VariationBrancher, recipe: Recipe, clock: Clock = SystemClock()) {
        self.brancher = brancher
        self.recipe = recipe
        self.clock = clock
    }

    var canBranch: Bool {
        !isBranching
            && pendingVariation == nil
            && !directive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Generate a variation proposal from the directive. Stores in
    /// `pendingVariation` for review — does NOT append to the recipe yet.
    func generate() async {
        guard let base = recipe.currentRevision else {
            errorMessage = "Recipe has no base revision to branch from."
            return
        }
        let trimmed = directive.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBranching = true
        defer { isBranching = false }

        do {
            let draft = try await brancher.branch(
                from: base,
                baseRecipeName: recipe.name,
                directive: trimmed
            )
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
            pendingVariation = Variation(
                name: draft.name.isEmpty ? trimmed : draft.name,
                directive: trimmed,
                createdAt: clock.now,
                revisions: [firstRev],
                feedback: []
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Commit the pending variation into the recipe. Returns the updated
    /// recipe for the caller to save.
    func apply() -> Recipe? {
        guard let pending = pendingVariation else { return nil }
        recipe.variations.append(pending)
        pendingVariation = nil
        directive = ""
        return recipe
    }

    /// Discard the pending variation without saving.
    func discard() {
        pendingVariation = nil
    }
}
