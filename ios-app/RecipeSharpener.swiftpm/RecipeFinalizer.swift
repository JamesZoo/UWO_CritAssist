import Foundation

struct RecipeAnalysis: Sendable, Codable, Hashable {
    var journeySummary: String
    var baseBestRevisionID: UUID
    var variationBestRevisionIDs: [UUID: UUID]
    var finalDocument: String
}

protocol RecipeFinalizer: Sendable {
    func finalize(recipe: Recipe) async throws -> RecipeAnalysis
}
