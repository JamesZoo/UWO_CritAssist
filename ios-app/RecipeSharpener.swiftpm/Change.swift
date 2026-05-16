import Foundation

enum ChangeKind: String, Codable, Sendable, CaseIterable, Hashable {
    case stepAdded
    case stepRemoved
    case stepEdited
    case ingredientAdded
    case ingredientRemoved
    case ingredientEdited
    case techniqueChanged
}

struct Change: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var kind: ChangeKind
    var summary: String
    var feedbackID: UUID?
    var targetStepID: UUID?
    var targetIngredientID: UUID?

    init(
        id: UUID = UUID(),
        kind: ChangeKind,
        summary: String,
        feedbackID: UUID? = nil,
        targetStepID: UUID? = nil,
        targetIngredientID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.feedbackID = feedbackID
        self.targetStepID = targetStepID
        self.targetIngredientID = targetIngredientID
    }
}
