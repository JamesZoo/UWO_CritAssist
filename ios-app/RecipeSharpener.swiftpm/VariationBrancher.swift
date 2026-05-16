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
    /// Branch a variation from `baseRevision` honoring `directive`. The
    /// `baseRecipeName` is passed explicitly so the AI can anchor the
    /// variation's name and identity to the base dish — the variation must
    /// remain a recognizable version of the same dish, not a different one.
    func branch(
        from baseRevision: Revision,
        baseRecipeName: String,
        directive: String
    ) async throws -> VariationDraft
}
