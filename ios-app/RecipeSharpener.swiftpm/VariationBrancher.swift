import Foundation

struct VariationDraft: Sendable, Codable, Hashable {
    var name: String
    var ingredients: [Ingredient]
    var steps: [Step]
    var referenceStyle: String?
    var rationale: String
    var changes: [Change]
}

protocol VariationBrancher: Sendable {
    func branch(
        from baseRevision: Revision,
        directive: String
    ) async throws -> VariationDraft
}
