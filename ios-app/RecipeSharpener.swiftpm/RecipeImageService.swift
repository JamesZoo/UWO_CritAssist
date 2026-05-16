import Foundation

struct RecipeImageResult: Sendable, Codable, Hashable {
    var imageURL: URL
    var attribution: ImageAttribution
}

protocol RecipeImageService: Sendable {
    func fetchImage(for dishName: String) async throws -> RecipeImageResult?
}
