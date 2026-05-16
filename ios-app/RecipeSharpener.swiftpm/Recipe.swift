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
    /// Number of people the recipe yields. nil if unknown.
    var servings: Int?
    /// Active preparation time in minutes (chopping, measuring, marinating).
    var prepMinutes: Int?
    /// Active cooking time in minutes (sauté, simmer, bake, etc.).
    var cookMinutes: Int?

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        createdAt: Date = Date(),
        revisions: [Revision] = [],
        variations: [Variation] = [],
        feedback: [Feedback] = [],
        imageURL: URL? = nil,
        imageAttribution: ImageAttribution? = nil,
        servings: Int? = nil,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil
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
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
    }

    var currentRevision: Revision? { revisions.last }

    var totalMinutes: Int? {
        switch (prepMinutes, cookMinutes) {
        case let (p?, c?): return p + c
        case let (p?, nil): return p
        case let (nil, c?): return c
        case (nil, nil): return nil
        }
    }
}
