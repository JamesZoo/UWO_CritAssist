import Foundation

/// Chains a primary image source (real photos from Wikipedia / Wikimedia, via
/// ValidatedImageService) with an AI-generation fallback. Real-photo path is
/// always preferred — the fallback only fires when the primary returns nil
/// (no valid public-source image found) or throws. The fallback's result is
/// labeled "AI generated" in its attribution chip so the user can tell.
struct FallbackImageService: RecipeImageService {
    let primary: RecipeImageService
    let fallback: (@Sendable (String) async throws -> RecipeImageResult?)?

    init(
        primary: RecipeImageService,
        fallback: (@Sendable (String) async throws -> RecipeImageResult?)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetchImage(for dishName: String) async throws -> RecipeImageResult? {
        if let primaryResult = try? await primary.fetchImage(for: dishName) {
            return primaryResult
        }
        guard let fallback else { return nil }
        return try? await fallback(dishName)
    }
}
