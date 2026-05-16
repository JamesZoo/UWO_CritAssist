import Foundation

struct WikimediaImageService: RecipeImageService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchImage(for dishName: String) async throws -> RecipeImageResult? {
        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let langs: [String] = containsCJK(trimmed) ? ["zh", "en"] : ["en", "zh"]
        for lang in langs {
            if let result = await fetchOne(dishName: trimmed, lang: lang) {
                return result
            }
        }
        return nil
    }

    private func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0x3040...0x30FF).contains(scalar.value)
                || (0xAC00...0xD7AF).contains(scalar.value)
        }
    }

    private func fetchOne(dishName: String, lang: String) async -> RecipeImageResult? {
        guard let encoded = dishName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://\(lang).wikipedia.org/w/api.php?action=query&format=json&prop=pageimages%7Cinfo&piprop=original%7Cthumbnail&pithumbsize=600&inprop=url&generator=search&gsrnamespace=0&gsrlimit=1&gsrsearch=\(encoded)"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let query = json["query"] as? [String: Any],
            let pages = query["pages"] as? [String: Any]
        else { return nil }

        for (_, pageAny) in pages {
            guard let page = pageAny as? [String: Any] else { continue }
            let originalDict = page["original"] as? [String: Any]
            let thumbDict = page["thumbnail"] as? [String: Any]
            let imageDict = originalDict ?? thumbDict
            guard
                let imgDict = imageDict,
                let src = imgDict["source"] as? String,
                let imageURL = URL(string: src)
            else { continue }
            let pageURL = (page["fullurl"] as? String).flatMap { URL(string: $0) }
            return RecipeImageResult(
                imageURL: imageURL,
                attribution: ImageAttribution(
                    sourceName: "Wikipedia",
                    pageURL: pageURL,
                    author: nil,
                    licenseName: "See Wikipedia page",
                    licenseURL: pageURL
                )
            )
        }
        return nil
    }
}
