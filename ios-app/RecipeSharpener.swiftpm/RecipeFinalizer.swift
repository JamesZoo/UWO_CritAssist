import Foundation

struct RecipeAnalysis: Sendable, Codable, Hashable {
    var journeySummary: String
    var baseBestRevisionID: UUID
    var variationBestRevisionIDs: [UUID: UUID]
    var finalDocument: String
    /// Number of people the final document was scaled to.
    var targetServings: Int
}

protocol RecipeFinalizer: Sendable {
    func finalize(recipe: Recipe, targetServings: Int) async throws -> RecipeAnalysis
}
