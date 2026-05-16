import Foundation

struct WebRecipeExtractor: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func extract(from url: URL, expectedDish: String?) async throws -> InitialRecipeDraft {
        var request = URLRequest(url: url)
        request.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw RecipeGeneratorError.parsingFailed("HTTP \(http.statusCode) from \(url.host() ?? "source")")
        }
        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw RecipeGeneratorError.parsingFailed("Could not decode page as text")
        }

        for block in jsonLDBlocks(in: html) {
            guard let parsed = try? JSONSerialization.jsonObject(with: Data(block.utf8), options: [.fragmentsAllowed]) else { continue }
            if let recipe = findRecipeNode(in: parsed) {
                return draft(from: recipe, fallbackName: expectedDish, sourceURL: url, html: html)
            }
        }

        throw RecipeGeneratorError.parsingFailed(
            "No structured recipe data was found at \(url.host() ?? "this URL"). Try the Paste mode if you can copy the text."
        )
    }

    private func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            return ns.substring(with: match.range(at: 1))
                .replacingOccurrences(of: "\u{2028}", with: " ")
                .replacingOccurrences(of: "\u{2029}", with: " ")
        }
    }

    private func findRecipeNode(in any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            if isRecipe(dict) { return dict }
            if let graph = dict["@graph"] {
                if let found = findRecipeNode(in: graph) { return found }
            }
            for (_, v) in dict {
                if let found = findRecipeNode(in: v) { return found }
            }
        }
        if let arr = any as? [Any] {
            for item in arr {
                if let found = findRecipeNode(in: item) { return found }
            }
        }
        return nil
    }

    private func isRecipe(_ dict: [String: Any]) -> Bool {
        if let s = dict["@type"] as? String { return s == "Recipe" }
        if let arr = dict["@type"] as? [String] { return arr.contains("Recipe") }
        return false
    }

    private func draft(from recipe: [String: Any], fallbackName: String?, sourceURL: URL, html: String) -> InitialRecipeDraft {
        // User-provided expectedDish wins so the recipe sticks with the name they typed,
        // not the source page's title. Page name is used only when no expectedDish was given.
        let userProvided = fallbackName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageName = (recipe["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String
        if let userProvided, !userProvided.isEmpty {
            name = userProvided
        } else if let pageName, !pageName.isEmpty {
            name = pageName
        } else {
            name = sourceURL.host() ?? "Imported recipe"
        }

        let summary = (recipe["description"] as? String) ?? "Imported from \(sourceURL.host() ?? "the web")."

        let ingredients = (recipe["recipeIngredient"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Ingredient(name: $0, quantity: "") }

        let stepStrings = parseInstructions(recipe["recipeInstructions"])
        let steps = stepStrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { Step(index: $0.offset + 1, text: $0.element) }

        let imageURL = extractImageURL(recipe["image"]) ?? extractOgImage(html: html)
        let authorName = extractAuthorName(recipe["author"])
        let attribution: ImageAttribution? = imageURL.map { _ in
            ImageAttribution(
                sourceName: sourceURL.host() ?? "Web source",
                pageURL: sourceURL,
                author: authorName,
                licenseName: nil,
                licenseURL: nil
            )
        }

        return InitialRecipeDraft(
            name: name,
            summary: summary,
            ingredients: ingredients,
            steps: steps.isEmpty
                ? [Step(index: 1, text: "(No instructions found in the page's structured data.)")]
                : steps,
            referenceStyle: sourceURL.host() ?? "Imported",
            imageURL: imageURL,
            imageAttribution: attribution
        )
    }

    private func parseInstructions(_ value: Any?) -> [String] {
        guard let value else { return [] }
        if let s = value as? String { return splitInstructionString(s) }
        if let arr = value as? [Any] {
            return arr.flatMap { item -> [String] in
                if let s = item as? String { return [s] }
                if let d = item as? [String: Any] {
                    let type = d["@type"] as? String
                    if type == "HowToStep", let t = d["text"] as? String { return [t] }
                    if type == "HowToSection" { return parseInstructions(d["itemListElement"]) }
                    if let t = d["text"] as? String { return [t] }
                }
                return []
            }
        }
        return []
    }

    private func splitInstructionString(_ s: String) -> [String] {
        let normalized = s.replacingOccurrences(of: "\r\n", with: "\n")
        let byLine = normalized
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if byLine.count > 1 { return byLine }
        return [normalized.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    private func extractImageURL(_ value: Any?) -> URL? {
        guard let value else { return nil }
        if let s = value as? String { return URL(string: s) }
        if let arr = value as? [Any] {
            for item in arr {
                if let u = extractImageURL(item) { return u }
            }
        }
        if let d = value as? [String: Any] {
            if let s = d["url"] as? String, let u = URL(string: s) { return u }
            if let s = d["contentUrl"] as? String, let u = URL(string: s) { return u }
        }
        return nil
    }

    private func extractAuthorName(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let d = value as? [String: Any] { return d["name"] as? String }
        if let arr = value as? [Any], let first = arr.first { return extractAuthorName(first) }
        return nil
    }

    private func extractOgImage(html: String) -> URL? {
        let pattern = #"<meta\s+(?:[^>]*\s+)?property=["']og:image["']\s+content=["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        guard let m = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2 else { return nil }
        return URL(string: ns.substring(with: m.range(at: 1)))
    }
}
