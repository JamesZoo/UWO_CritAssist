import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Per-recipe `LanguageModelSession` storage for the refinement loop. The
/// first refine() call for a recipe creates a session; subsequent calls
/// reuse it so the model retains memory of prior refinements' reasoning,
/// diagnoses, and the evolving recipe state.
///
/// Sessions are not shared across recipes. Reset is called when the user
/// undoes a refinement (the session's "memory" no longer matches the
/// recipe's actual state), or when the session's own context window
/// overflows and we need to start fresh.
///
/// State is in-memory only — restarting the app starts every recipe with
/// a fresh session. This is acceptable because the recipe's persisted
/// state is the ground truth; the session memory is an optimization for
/// reasoning continuity within a session.
@MainActor
final class RecipeRefinementSessionStore {
    private struct State {
        let session: LanguageModelSession
        var hasSentRecipe: Bool
    }

    private var states: [UUID: State] = [:]

    /// Returns the session for the recipe (creating one if needed) and a
    /// flag indicating whether this is the first refine call for the
    /// recipe (true = the model has not yet seen the recipe text).
    func sessionForRefinement(recipeID: UUID, instructions: String) -> (session: LanguageModelSession, isFirstCall: Bool) {
        if let existing = states[recipeID] {
            return (existing.session, !existing.hasSentRecipe)
        }
        let new = LanguageModelSession(instructions: instructions)
        states[recipeID] = State(session: new, hasSentRecipe: false)
        return (new, true)
    }

    func markRecipeSent(for recipeID: UUID) {
        states[recipeID]?.hasSentRecipe = true
    }

    func reset(for recipeID: UUID) {
        states.removeValue(forKey: recipeID)
    }

    func resetAll() {
        states.removeAll()
    }
}
#else
/// No-op stub for environments without FoundationModels — used so the
/// composition root and AppleIntelligenceRecipeRefiner can reference the
/// type unconditionally.
@MainActor
final class RecipeRefinementSessionStore {
    func reset(for recipeID: UUID) {}
    func resetAll() {}
}
#endif
