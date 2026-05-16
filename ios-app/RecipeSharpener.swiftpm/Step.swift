import Foundation

struct Step: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var index: Int
    var text: String
    var technique: String?
    var estimatedMinutes: Int?

    init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        technique: String? = nil,
        estimatedMinutes: Int? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.technique = technique
        self.estimatedMinutes = estimatedMinutes
    }
}
