import Foundation

/// One photo fetched from a Wikipedia article, with the caption text that
/// describes it. Used by `AppleIntelligenceStepIllustrator` to match real
/// photos to recipe steps.
struct ArticleStepPhoto: Sendable {
    let imageURL: URL
    let description: String
}

/// Fetches photos embedded in a Wikipedia article for a dish name, together
/// with their captions. The captions are what the AI uses to decide which
/// cooking step each photo illustrates.
///
/// API sequence:
///   1. Search Wikipedia for the article title matching the dish name.
///   2. `prop=images` — get all image file names used in the article.
///   3. `prop=imageinfo&iiprop=url|extmetadata` — batch-fetch URLs and
///      caption text (from `extmetadata.ImageDescription`) for each image.
///
/// Filters out SVGs, icons, logos, flags, and other non-photo files before
/// returning.
struct WikimediaStepPhotoService: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchArticlePhotos(for dishName: String, limit: Int = 15) async -> [ArticleStepPhoto] {
        let langs: [String] = LanguageHeuristics.containsCJK(dishName) ? ["zh", "en"] : ["en", "zh"]
        for lang in langs {
            let photos = await fetchPhotos(dishName: dishName, lang: lang, limit: limit)
            if !photos.isEmpty { return photos }
        }
        return []
    }

    private func fetchPhotos(dishName: String, lang: String, limit: Int) async -> [ArticleStepPhoto] {
        guard let title = await findArticleTitle(dishName: dishName, lang: lang) else { return [] }
        let fileNames = await fetchImageFileNames(articleTitle: title, lang: lang, limit: limit)
        guard !fileNames.isEmpty else { return [] }
        return await fetchImageInfo(fileNames: fileNames, lang: lang)
    }

    private func findArticleTitle(dishName: String, lang: String) async -> String? {
        guard let encoded = dishName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://\(lang).wikipedia.org/w/api.php?action=query&format=json&generator=search&gsrsearch=\(encoded)&gsrlimit=1&gsrnamespace=0&prop=info"
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await session.data(for: req) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let query = json["query"] as? [String: Any],
            let pages = query["pages"] as? [String: Any],
            let page = pages.values.first as? [String: Any],
            let title = page["title"] as? String
        else { return nil }
        return title
    }

    private func fetchImageFileNames(articleTitle: String, lang: String, limit: Int) async -> [String] {
        guard let encoded = articleTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let urlStr = "https://\(lang).wikipedia.org/w/api.php?action=query&format=json&prop=images&titles=\(encoded)&imlimit=\(limit)"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await session.data(for: req) else { return [] }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let query = json["query"] as? [String: Any],
            let pages = query["pages"] as? [String: Any],
            let page = pages.values.first as? [String: Any],
            let images = page["images"] as? [[String: Any]]
        else { return [] }
        return images
            .compactMap { $0["title"] as? String }
            .filter(Self.isUsableImageFile)
    }

    private static func isUsableImageFile(_ title: String) -> Bool {
        let lower = title.lowercased()
        guard lower.hasPrefix("file:") else { return false }
        let allowedExts = [".jpg", ".jpeg", ".png", ".webp"]
        guard allowedExts.contains(where: { lower.hasSuffix($0) }) else { return false }
        let skipWords = ["logo", "flag", "icon", "symbol", "map", "blank", "arrow",
                         "button", "template", "wikidata", "commons-logo", "wikisource"]
        return !skipWords.contains(where: { lower.contains($0) })
    }

    /// Batch-fetches imageinfo for up to 10 file names, returning results in
    /// the same order as the input list. The Wikipedia API returns pages as an
    /// unordered dict, so we re-sort by matching titles.
    private func fetchImageInfo(fileNames: [String], lang: String) async -> [ArticleStepPhoto] {
        let batch = Array(fileNames.prefix(10))
        let titlesStr = batch.joined(separator: "|")
        guard let encoded = titlesStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let urlStr = "https://\(lang).wikipedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url%7Cextmetadata&iiurlwidth=600&titles=\(encoded)"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await session.data(for: req) else { return [] }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let query = json["query"] as? [String: Any],
            let pages = query["pages"] as? [String: Any]
        else { return [] }

        var photoByTitle: [String: ArticleStepPhoto] = [:]
        for (_, pageAny) in pages {
            guard
                let page = pageAny as? [String: Any],
                let title = page["title"] as? String,
                let infos = page["imageinfo"] as? [[String: Any]],
                let info = infos.first
            else { continue }
            let thumbStr = info["thumburl"] as? String
            let origStr = info["url"] as? String
            guard let srcStr = thumbStr ?? origStr, let imageURL = URL(string: srcStr) else { continue }
            let extmeta = info["extmetadata"] as? [String: Any]
            let rawDesc = (extmeta?["ImageDescription"] as? [String: Any])?["value"] as? String ?? ""
            let desc = Self.stripHTML(rawDesc)
            photoByTitle[title] = ArticleStepPhoto(imageURL: imageURL, description: desc)
        }
        return batch.compactMap { photoByTitle[$0] }
    }

    private static func stripHTML(_ html: String) -> String {
        guard !html.isEmpty else { return "" }
        var s = html
        for tag in ["</p>", "</div>", "<br>", "<br/>", "<br />", "</li>"] {
            s = s.replacingOccurrences(of: tag, with: " ", options: .caseInsensitive)
        }
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
