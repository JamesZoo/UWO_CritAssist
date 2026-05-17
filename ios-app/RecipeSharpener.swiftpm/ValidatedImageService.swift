import Foundation

/// Wraps an image service with AI-based validation. After the base service
/// returns a candidate image, asks the validator whether the article's hero
/// photo is food-related at all. Accepts any food or cooking image; rejects
/// only clearly non-food articles (geography, architecture, etc.). If
/// rejected, tries alternative dish names before falling through to no image.
/// The validator no longer tries to match the photo to the specific dish —
/// that was too strict and rejected useful food photos.
struct ValidatedImageService: RecipeImageService {
    let base: RecipeImageService
    let validator: DishImageMatchValidator?
    let alternativeNameProvider: DishAlternativeNameProvider?
    let maxRetries: Int

    init(
        base: RecipeImageService,
        validator: DishImageMatchValidator?,
        alternativeNameProvider: DishAlternativeNameProvider?,
        maxRetries: Int = 2
    ) {
        self.base = base
        self.validator = validator
        self.alternativeNameProvider = alternativeNameProvider
        self.maxRetries = maxRetries
    }

    func fetchImage(for dishName: String) async throws -> RecipeImageResult? {
        if let result = try? await base.fetchImage(for: dishName) {
            if await passesValidation(result: result, dishName: dishName) {
                return result
            }
        }

        guard let provider = alternativeNameProvider else { return nil }
        let alternatives: [String]
        do {
            alternatives = try await provider.suggestAlternativeNames(for: dishName)
        } catch {
            return nil
        }

        for alt in alternatives.prefix(maxRetries) {
            if let result = try? await base.fetchImage(for: alt) {
                if await passesValidation(result: result, dishName: dishName) {
                    return result
                }
            }
        }
        return nil
    }

    private func passesValidation(result: RecipeImageResult, dishName: String) async -> Bool {
        guard let validator else { return true }
        guard let title = result.attribution.title, !title.isEmpty else {
            // No article title — can't validate, accept as-is rather than
            // throw away an otherwise good source.
            return true
        }
        do {
            return try await validator.validateImageMatch(articleTitle: title, dishName: dishName)
        } catch {
            // Validation failed at the model layer — accept the image rather
            // than block on a transient AI error.
            return true
        }
    }
}
