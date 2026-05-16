import Foundation

struct Variation: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var directive: String
    var createdAt: Date
    var revisions: [Revision]
    var feedback: [Feedback]

    init(
        id: UUID = UUID(),
        name: String,
        directive: String,
        createdAt: Date = Date(),
        revisions: [Revision] = [],
        feedback: [Feedback] = []
    ) {
        self.id = id
        self.name = name
        self.directive = directive
        self.createdAt = createdAt
        self.revisions = revisions
        self.feedback = feedback
    }

    var currentRevision: Revision? { revisions.last }
}
