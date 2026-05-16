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
    /// When non-nil, new variations branch from this variation's current
    /// revision instead of the base recipe. Lets users compound variations
    /// (e.g. "Vegetarian Kung Pao" branching from "Mild Kung Pao") rather
    /// than always starting from the base.
    var branchFromVariationID: UUID?

    init(brancher: VariationBrancher, recipe: Recipe, clock: Clock = SystemClock()) {
        self.brancher = brancher
        self.recipe = recipe
        self.clock = clock
    }

    var canBranch: Bool {
        !isBranching
            && pendingVariation == nil
            && !directive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && branchSource != nil
    }

    /// The revision the next variation will be branched from, and its
    /// display name. Returns nil only if the recipe has no usable base
    /// (shouldn't happen in practice).
    var branchSource: (revision: Revision, name: String)? {
        if let varID = branchFromVariationID,
           let variation = recipe.variations.first(where: { $0.id == varID }),
           let varRev = variation.currentRevision {
            return (varRev, variation.name)
        }
        if let baseRev = recipe.currentRevision {
            return (baseRev, recipe.name)
        }
        return nil
    }

    /// Display string for the current branch source, used in the picker label.
    var branchSourceLabel: String {
        if let varID = branchFromVariationID,
           let v = recipe.variations.first(where: { $0.id == varID }) {
            return v.name
        }
        return "\(recipe.name) (base)"
    }

    /// Generate a variation proposal from the directive. Stores in
    /// `pendingVariation` for review — does NOT append to the recipe yet.
    func generate() async {
        guard let source = branchSource else {
            errorMessage = "Recipe has no base revision to branch from."
            return
        }
        let trimmed = directive.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBranching = true
        defer { isBranching = false }

        do {
            let draft = try await brancher.branch(
                from: source.revision,
                baseRecipeName: source.name,
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
