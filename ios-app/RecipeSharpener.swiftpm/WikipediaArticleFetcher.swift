import Foundation

/// Fetches the plain-text content of a Wikipedia article for a given dish
/// name, preferring the dish's native-language Wikipedia. Used by
/// `WikipediaGroundedRecipeGenerator` so the AI synthesizes recipes from
/// authentic native-language source material rather than its own training
/// data — fixes the cultural-context and translation-drift problems
/// (e.g. "pork belly" being translated to 猪肚 / pork stomach instead of
/// the correct 五花肉).
///
/// CJK dish names try `zh.wikipedia.org` first; everything else tries
/// `en.wikipedia.org` first. Falls through to the other language if the
/// first attempt returns nothing.
///
/// Uses the MediaWiki API's `prop=extracts` with `explaintext=true` and
/// `generator=search` to get the top search hit's plain-text body. The
/// extract is truncated to `maxExtractLength` characters so the result
/// fits comfortably inside the LLM's context window even with the
/// system prompt and structured-output schema.
struct WikipediaArticleFetcher: Sendable {
    let session: URLSession
    /// Truncate the article extract to this many characters before passing
    /// to the LLM. 2500 chars ≈ 1000 tokens, leaving plenty of room in the
    /// 4096-token context for the parser system prompt and the structured
    /// output.
    let maxExtractLength: Int

    init(session: URLSession = .shared, maxExtractLength: Int = 2500) {
        self.session = session
        self.maxExtractLength = maxExtractLength
    }

    func fetchArticle(for dishName: String) async -> WikipediaArticle? {
        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let langs: [String] = LanguageHeuristics.containsCJK(trimmed) ? ["zh", "en"] : ["en", "zh"]
        for lang in langs {
            if let result = await fetchOne(dishName: trimmed, lang: lang) {
                return result
            }
        }
        return nil
    }

    private func fetchOne(dishName: String, lang: String) async -> WikipediaArticle? {
        guard let encoded = dishName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://\(lang).wikipedia.org/w/api.php?action=query&format=json&prop=extracts%7Cinfo&explaintext=true&exsectionformat=plain&inprop=url&generator=search&gsrnamespace=0&gsrlimit=1&gsrsearch=\(encoded)"
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
            guard let rawExtract = page["extract"] as? String, !rawExtract.isEmpty else { continue }
            let title = page["title"] as? String ?? dishName
            let pageURL = (page["fullurl"] as? String).flatMap { URL(string: $0) }
            let extract = rawExtract.count > maxExtractLength
                ? String(rawExtract.prefix(maxExtractLength))
                : rawExtract
            return WikipediaArticle(
                title: title,
                extract: extract,
                pageURL: pageURL,
                language: lang
            )
        }
        return nil
    }
}

struct WikipediaArticle: Sendable, Hashable {
    let title: String
    let extract: String
    let pageURL: URL?
    let language: String
}
