import Foundation

struct Ingredient: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var quantity: String
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.notes = notes
    }
}
