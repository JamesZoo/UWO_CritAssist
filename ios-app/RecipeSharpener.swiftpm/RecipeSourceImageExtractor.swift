import Foundation

/// Extracts per-step images from a recipe source page using JSON-LD
/// structured data. `recipeInstructions` in Schema.org Recipe markup
/// can include an `image` field on each `HowToStep` node; these are
/// directly tied to their step by position and are always article
/// content — never ads or tracking pixels.
///
/// Returns empty when the page has no JSON-LD recipe schema, no
/// per-step images, or can't be fetched. The caller falls back to
/// Wikipedia article photos in that case.
struct RecipeSourceImageExtractor: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns `(stepIndex, remoteURL)` pairs. `stepIndex` is 1-based,
    /// matching the recipe's `Step.index` values. Only steps that have
    /// an image in the JSON-LD are included; others are omitted.
    func extractStepImages(from url: URL, stepCount: Int) async -> [(stepIndex: Int, imageURL: URL)] {
        guard let html = await fetchHTML(url) else { return [] }
        return parseJSONLD(html: html, stepCount: stepCount)
    }

    private func fetchHTML(_ url: URL) async -> String? {
        var req = URLRequest(url: url)
        req.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        guard
            let (data, response) = try? await session.data(for: req),
            let http = response as? HTTPURLResponse,
            (200..<400).contains(http.statusCode)
        else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    private func parseJSONLD(html: String, stepCount: Int) -> [(stepIndex: Int, imageURL: URL)] {
        for block in jsonLDBlocks(in: html) {
            guard
                let parsed = try? JSONSerialization.jsonObject(with: Data(block.utf8)),
                let recipe = findRecipeNode(in: parsed)
            else { continue }
            let pairs = stepImagePairs(from: recipe, stepCount: stepCount)
            if !pairs.isEmpty { return pairs }
        }
        return []
    }

    private func stepImagePairs(from recipe: [String: Any], stepCount: Int) -> [(stepIndex: Int, imageURL: URL)] {
        let steps = flattenSteps(recipe["recipeInstructions"])
        var result: [(stepIndex: Int, imageURL: URL)] = []
        for (i, step) in steps.enumerated() {
            let idx = i + 1
            guard idx <= stepCount else { break }
            if let url = firstImageURL(in: step["image"]) {
                result.append((stepIndex: idx, imageURL: url))
            }
        }
        return result
    }

    private func flattenSteps(_ value: Any?) -> [[String: Any]] {
        guard let value else { return [] }
        if let arr = value as? [Any] {
            return arr.flatMap { item -> [[String: Any]] in
                guard let d = item as? [String: Any] else { return [] }
                let type = d["@type"] as? String
                if type == "HowToStep" { return [d] }
                if type == "HowToSection" { return flattenSteps(d["itemListElement"]) }
                return []
            }
        }
        return []
    }

    private func firstImageURL(in value: Any?) -> URL? {
        guard let value else { return nil }
        if let s = value as? String { return URL(string: s) }
        if let d = value as? [String: Any] {
            if let s = d["url"] as? String { return URL(string: s) }
            if let s = d["contentUrl"] as? String { return URL(string: s) }
        }
        if let arr = value as? [Any] {
            for item in arr {
                if let u = firstImageURL(in: item) { return u }
            }
        }
        return nil
    }

    private func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard m.numberOfRanges >= 2 else { return nil }
            return ns.substring(with: m.range(at: 1))
        }
    }

    private func findRecipeNode(in any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            if isRecipe(dict) { return dict }
            if let graph = dict["@graph"], let found = findRecipeNode(in: graph) { return found }
            for (_, v) in dict { if let found = findRecipeNode(in: v) { return found } }
        }
        if let arr = any as? [Any] {
            for item in arr { if let found = findRecipeNode(in: item) { return found } }
        }
        return nil
    }

    private func isRecipe(_ dict: [String: Any]) -> Bool {
        if let s = dict["@type"] as? String { return s == "Recipe" }
        if let arr = dict["@type"] as? [String] { return arr.contains("Recipe") }
        return false
    }
}
