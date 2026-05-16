import Foundation

/// Wraps an image service with AI-based validation. After the base service
/// returns a candidate image, asks the validator whether the article it came
/// from is actually about the dish in question. If the answer is no, asks
/// the alternative-name provider for other search terms and retries. Falls
/// through to no image (placeholder) if all attempts are rejected.
///
/// Addresses the case where Wikipedia search matches a broader cuisine
/// article (e.g. 广东菜 for 广式红烧肉) whose hero image is unrelated to
/// the user's dish.
struct ValidatedImageService: RecipeImageService {
    let base: RecipeImageService
    let validator: (@Sendable (String, String) async throws -> Bool)?
    let alternativeNameProvider: (@Sendable (String) async throws -> [String])?
    let maxRetries: Int

    init(
        base: RecipeImageService,
        validator: (@Sendable (String, String) async throws -> Bool)?,
        alternativeNameProvider: (@Sendable (String) async throws -> [String])?,
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
            alternatives = try await provider(dishName)
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
            return try await validator(title, dishName)
        } catch {
            // Validation failed at the model layer — accept the image rather
            // than block on a transient AI error.
            return true
        }
    }
}
