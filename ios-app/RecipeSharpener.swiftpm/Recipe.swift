import Foundation

struct Recipe: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var createdAt: Date
    var revisions: [Revision]
    var variations: [Variation]
    var feedback: [Feedback]
    var imageURL: URL?
    var imageAttribution: ImageAttribution?

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        createdAt: Date = Date(),
        revisions: [Revision] = [],
        variations: [Variation] = [],
        feedback: [Feedback] = [],
        imageURL: URL? = nil,
        imageAttribution: ImageAttribution? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.createdAt = createdAt
        self.revisions = revisions
        self.variations = variations
        self.feedback = feedback
        self.imageURL = imageURL
        self.imageAttribution = imageAttribution
    }

    var currentRevision: Revision? { revisions.last }
}
