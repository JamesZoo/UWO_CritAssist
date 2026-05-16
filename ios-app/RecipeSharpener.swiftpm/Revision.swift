import Foundation

struct Revision: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var index: Int
    var createdAt: Date
    var ingredients: [Ingredient]
    var steps: [Step]
    var referenceStyle: String?
    var rationale: String
    var changes: [Change]
    var addressedFeedbackIDs: [UUID]

    init(
        id: UUID = UUID(),
        index: Int,
        createdAt: Date = Date(),
        ingredients: [Ingredient] = [],
        steps: [Step] = [],
        referenceStyle: String? = nil,
        rationale: String = "",
        changes: [Change] = [],
        addressedFeedbackIDs: [UUID] = []
    ) {
        self.id = id
        self.index = index
        self.createdAt = createdAt
        self.ingredients = ingredients
        self.steps = steps
        self.referenceStyle = referenceStyle
        self.rationale = rationale
        self.changes = changes
        self.addressedFeedbackIDs = addressedFeedbackIDs
    }
}
