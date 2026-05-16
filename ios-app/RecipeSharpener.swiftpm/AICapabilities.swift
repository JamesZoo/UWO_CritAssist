import Foundation

/// A cooking-in-action moment in a recipe worth illustrating. Returned by
/// a `StepIllustrator`. Plain Swift type (no `@Generable` / no FoundationModels
/// dependency) so any AI backend can synthesize one — the Apple Intelligence
/// implementation uses an internal `@Generable` mirror and converts.
struct KeyVisualMoment: Sendable, Hashable, Codable {
    var stepIndex: Int
    var imagePrompt: String
}

/// Picks the few moments in a recipe worth illustrating, and renders a
/// single illustration from a prompt. The two methods are paired in one
/// protocol because they're driven by the same backend resources
/// (ImagePlayground on Apple Intelligence; an image API on Claude).
protocol StepIllustrator: Sendable {
    func selectKeyMoments(in revision: Revision, dishName: String) async throws -> [KeyVisualMoment]
    func generateImage(prompt: String) async throws -> URL
}

/// Generates a representative profile image for a dish when no public-source
/// photo is available. Output is meant to be labeled "AI generated" by the
/// caller so the user can tell.
protocol ProfileImageGenerator: Sendable {
    func generateRecipeImage(for dishName: String) async throws -> RecipeImageResult
}

/// Translates an extracted recipe into a target language while preserving
/// the ingredient / step structure. Used by `DefaultRecipeGenerator` to
/// reconcile a parsed web page with the user's expected-dish description
/// language.
protocol RecipeTranslator: Sendable {
    func translateDraft(_ draft: InitialRecipeDraft, toLanguage language: String) async throws -> InitialRecipeDraft
}

/// AI judge that decides whether a Wikipedia article's typical hero image
/// is visually similar enough to the named dish to serve as a representative
/// photo. Powers `ValidatedImageService`'s rejection of broad-cuisine matches.
protocol DishImageMatchValidator: Sendable {
    func validateImageMatch(articleTitle: String, dishName: String) async throws -> Bool
}

/// Suggests alternate names / spellings of a dish for fallback image lookup
/// (English translation, romanization, main-ingredient name). Used by
/// `ValidatedImageService` after a primary match is rejected.
protocol DishAlternativeNameProvider: Sendable {
    func suggestAlternativeNames(for dishName: String) async throws -> [String]
}
