import Foundation

actor FileSystemRecipeStore: RecipeStore {
    let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    static func localDocuments() throws -> FileSystemRecipeStore {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try FileSystemRecipeStore(directoryURL: docs.appending(path: "Recipes"))
    }

    func allRecipes() async throws -> [Recipe] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Recipe.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func recipe(id: UUID) async throws -> Recipe? {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Recipe.self, from: data)
    }

    func save(_ recipe: Recipe) async throws {
        let data = try encoder.encode(recipe)
        try data.write(to: fileURL(for: recipe.id), options: .atomic)
    }

    func delete(id: UUID) async throws {
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func wipeAll() async throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        for url in urls where url.pathExtension == "json" {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func seedIfEmpty(_ recipes: [Recipe]) async throws {
        let existing = try await allRecipes()
        guard existing.isEmpty else { return }
        for r in recipes { try await save(r) }
    }

    private func fileURL(for id: UUID) -> URL {
        directoryURL.appending(path: "\(id.uuidString).json")
    }
}
