import Foundation

struct Step: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var index: Int
    var text: String
    var technique: String?
    var estimatedMinutes: Int?
    /// Optional URL of a generated or sourced illustration for this step.
    /// Populated by a future image-generation service (ImagePlayground or
    /// an alternative). nil when no illustration is available.
    var imageURL: URL?

    init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        technique: String? = nil,
        estimatedMinutes: Int? = nil,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.technique = technique
        self.estimatedMinutes = estimatedMinutes
        self.imageURL = imageURL
    }
}
