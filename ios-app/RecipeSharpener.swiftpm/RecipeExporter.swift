import Foundation

enum RecipeExporter {
    static func encode(_ recipes: [Recipe]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(recipes)
    }

    static func decode(_ data: Data) throws -> [Recipe] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Recipe].self, from: data)
    }

    static func writeTempFile(_ recipes: [Recipe]) throws -> URL {
        let data = try encode(recipes)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "recipe-sharpener-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
