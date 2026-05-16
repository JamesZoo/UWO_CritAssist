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

        // Tier 1: JSON-LD structured data (highest fidelity)
        for block in jsonLDBlocks(in: html) {
            guard let parsed = try? JSONSerialization.jsonObject(with: Data(block.utf8), options: [.fragmentsAllowed]) else { continue }
            if let recipe = findRecipeNode(in: parsed) {
                return draft(from: recipe, fallbackName: expectedDish, sourceURL: url, html: html)
            }
        }

        // Tier 2: heuristic plain-text fallback for pages that don't publish JSON-LD
        if let fallback = parsePlainTextFallback(html: html, sourceURL: url, expectedDish: expectedDish) {
            return fallback
        }

        throw RecipeGeneratorError.parsingFailed(
            "Could not extract a recipe from \(url.host() ?? "this URL"). Try the Paste mode if you can copy the text."
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

    // MARK: - Tier 2: heuristic plain-text fallback

    private func parsePlainTextFallback(html: String, sourceURL: URL, expectedDish: String?) -> InitialRecipeDraft? {
        let text = htmlToPlainText(html)
        let lines = text.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let ingredientHeaders = [
            "ingredients", "ingredient list", "what you'll need", "what you need",
            "用料", "食材", "配料", "主料", "辅料", "材料", "原料"
        ]
        let stepHeaders = [
            "directions", "instructions", "method", "steps", "preparation",
            "how to make", "to make", "procedure",
            "做法", "步骤", "方法", "制作步骤", "制作过程", "操作步骤",
            "烹饪步骤", "烹制方法", "制作方法"
        ]
        let endHeaders = [
            "notes", "nutrition", "comments", "reviews", "rate this",
            "you might also like", "related recipes", "tips", "more recipes",
            "about", "author", "leave a review", "video",
            "小贴士", "小窍门", "温馨提示", "提示", "注意事项", "厨师特别提醒",
            "评论", "相关推荐", "推荐阅读", "热门评论"
        ]

        guard let ingStart = firstLine(in: lines, matchingHeader: ingredientHeaders) else { return nil }
        guard let stepStart = firstLine(in: lines, matchingHeader: stepHeaders, startingAt: ingStart + 1) else { return nil }
        let stepEnd = firstLine(in: lines, matchingHeader: endHeaders, startingAt: stepStart + 1) ?? lines.count

        let ingredientItems = lines[(ingStart + 1)..<stepStart]
            .filter { $0.count < 200 && $0.count > 1 }
            .filter { !looksLikeNavOrNoise($0) }
            .map { Ingredient(name: $0, quantity: "") }

        let stepItems = lines[(stepStart + 1)..<stepEnd]
            .filter { $0.count > 2 }
            .filter { !looksLikeNavOrNoise($0) }
            .map { stripLeadingStepNumber($0) }
            .enumerated()
            .map { Step(index: $0.offset + 1, text: $0.element) }

        guard !ingredientItems.isEmpty || !stepItems.isEmpty else { return nil }

        let userProvided = expectedDish?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String = (userProvided?.isEmpty == false) ? userProvided! : (sourceURL.host() ?? "Imported recipe")

        let imageURL = extractOgImage(html: html)
        let attribution: ImageAttribution? = imageURL.map { _ in
            ImageAttribution(
                sourceName: sourceURL.host() ?? "Web source",
                pageURL: sourceURL,
                author: nil,
                licenseName: nil,
                licenseURL: nil
            )
        }

        return InitialRecipeDraft(
            name: name,
            summary: "Imported from \(sourceURL.host() ?? "the web") via heuristic extraction. Review and trim — AI cleanup will replace this path once FoundationModels is wired.",
            ingredients: ingredientItems,
            steps: stepItems,
            referenceStyle: sourceURL.host() ?? "Imported",
            imageURL: imageURL,
            imageAttribution: attribution
        )
    }

    private func firstLine(in lines: [String], matchingHeader keywords: [String], startingAt: Int = 0) -> Int? {
        guard startingAt < lines.count else { return nil }
        let trimSet = CharacterSet(charactersIn: " \t:.：。、，；！？【】《》「」『』()（）●○■□▶▼※#＃•★☆")

        // Pass 1: exact-or-prefix header matches on short lines.
        for i in startingAt..<lines.count {
            let cleaned = lines[i].lowercased().trimmingCharacters(in: trimSet)
            guard cleaned.count > 0 && cleaned.count < 100 else { continue }
            for kw in keywords {
                let k = kw.lowercased()
                if cleaned == k
                    || cleaned.hasPrefix(k + " ")
                    || cleaned.hasPrefix(k + ":")
                    || cleaned.hasPrefix(k + "：")
                    || cleaned.hasSuffix(" " + k)
                    || cleaned.hasSuffix("：" + k)
                {
                    return i
                }
            }
        }
        // Pass 2: short line containing the keyword anywhere — catches inline markup
        // like 【用料】 or wrapping characters we didn't anticipate.
        for i in startingAt..<lines.count {
            let l = lines[i].lowercased()
            guard l.count < 30 else { continue }
            if keywords.contains(where: { l.contains($0.lowercased()) }) {
                return i
            }
        }
        return nil
    }

    private func looksLikeNavOrNoise(_ line: String) -> Bool {
        let lower = line.lowercased()
        let noiseKeywords = [
            "subscribe", "sign up", "log in", "newsletter", "advertisement",
            "follow us", "share this", "print", "save", "jump to", "©",
            "cookie", "privacy policy", "terms of use",
            "登录", "注册", "广告", "返回顶部", "举报", "分享", "收藏",
            "声明：", "免责声明", "版权", "查看更多"
        ]
        return noiseKeywords.contains(where: lower.contains)
    }

    private func stripLeadingStepNumber(_ s: String) -> String {
        s.replacing(/^(?:step\s*|第)?\d+[.):、)]\s*/.ignoresCase(), with: "")
    }

    private func htmlToPlainText(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<noscript[\\s\\S]*?</noscript>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        let blockBreaks = ["</p>", "</div>", "</li>", "<br>", "<br/>", "<br />", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</tr>", "</section>", "</article>", "</header>", "</footer>"]
        for tag in blockBreaks {
            s = s.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&hellip;", "…"),
            ("&ndash;", "–"), ("&mdash;", "—"), ("&deg;", "°")
        ]
        for (k, v) in entities {
            s = s.replacingOccurrences(of: k, with: v)
        }
        // Numeric entities &#NNN;
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let ns = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed()
            var work = ns as String
            for m in matches where m.numberOfRanges >= 2 {
                let num = (work as NSString).substring(with: m.range(at: 1))
                if let code = UInt32(num), let scalar = Unicode.Scalar(code) {
                    work = (work as NSString).replacingCharacters(in: m.range, with: String(Character(scalar)))
                }
            }
            s = work
        }
        let perLine = s.split(separator: "\n").map { line -> String in
            String(line)
                .replacingOccurrences(of: "[\\s]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        return perLine.joined(separator: "\n")
    }
}
