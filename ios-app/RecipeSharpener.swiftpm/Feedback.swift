import Foundation

struct Feedback: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var text: String
    var rating: Int?
    var createdAt: Date
    var revisionID: UUID
    var testerNote: String?

    init(
        id: UUID = UUID(),
        text: String,
        rating: Int? = nil,
        createdAt: Date = Date(),
        revisionID: UUID,
        testerNote: String? = nil
    ) {
        self.id = id
        self.text = text
        self.rating = rating
        self.createdAt = createdAt
        self.revisionID = revisionID
        self.testerNote = testerNote
    }
}
