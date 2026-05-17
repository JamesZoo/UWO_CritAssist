import Foundation

/// Fetches Wikipedia photos for a recipe's dish, matches them to cooking
/// steps by caption text, downloads the matched images, and returns a list
/// of (stepIndex, local file URL) pairs. Steps with no matching photo are
/// omitted. Returns an empty list when no relevant photos are found.
protocol StepIllustrator: Sendable {
    /// Fetches real photos for the recipe's steps. Tries JSON-LD step images
    /// from `sourceURL` first (recipe sites embed per-step photos in structured
    /// data; these are always article content, never ads). Falls back to
    /// Wikipedia article photos matched by caption. Returns empty if neither
    /// source yields images.
    func illustrateSteps(in revision: Revision, dishName: String, sourceURL: URL?) async throws -> [(stepIndex: Int, imageURL: URL)]
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
