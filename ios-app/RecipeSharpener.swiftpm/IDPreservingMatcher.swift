import Foundation

/// Match AI-generated ingredient lines and step texts against an existing
/// base revision's items, reusing the base's IDs for content-similar
/// matches. This is what makes `RevisionDiffer` produce meaningful diffs
/// for refinement and variation output — without it, every AI call would
/// generate fresh UUIDs and the diff would show every base item as
/// "removed" and every new item as "added" even when 90% of the content
/// is the same.
///
/// The similarity metric is Jaccard over characters (for CJK input) or
/// over words (for non-CJK). 50% similarity is the match threshold —
/// empirically catches "Add 1 tbsp Shaoxing wine" matching "Add 2 tbsp
/// Shaoxing wine" while still treating "Sear meat" and "Add aromatics"
/// as different steps.
///
/// Matching is greedy and one-to-one: a base item can only be claimed by
/// the first generated item that scores above the threshold against it.
/// Subsequent generated items that would have also matched fall through
/// to "new ID, treated as added".
enum IDPreservingMatcher {
    static let similarityThreshold: Double = 0.5

    static func matchIngredients(generated: [String], against base: [Ingredient]) -> [Ingredient] {
        var result: [Ingredient] = []
        var usedBaseIDs: Set<UUID> = []
        for line in generated {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let match = bestIngredientMatch(for: trimmed, in: base, excluding: usedBaseIDs) {
                usedBaseIDs.insert(match.id)
                result.append(Ingredient(
                    id: match.id,
                    name: trimmed,
                    quantity: "",
                    notes: match.notes
                ))
            } else {
                result.append(Ingredient(name: trimmed, quantity: ""))
            }
        }
        return result
    }

    static func matchSteps(generatedTexts: [String], against base: [Step]) -> [Step] {
        var result: [Step] = []
        var usedBaseIDs: Set<UUID> = []
        for (index, text) in generatedTexts.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let match = bestStepMatch(for: trimmed, in: base, excluding: usedBaseIDs) {
                usedBaseIDs.insert(match.id)
                result.append(Step(
                    id: match.id,
                    index: index + 1,
                    text: trimmed,
                    technique: match.technique,
                    estimatedMinutes: match.estimatedMinutes,
                    temperatureC: match.temperatureC,
                    doneness: match.doneness,
                    imageURL: match.imageURL
                ))
            } else {
                result.append(Step(index: index + 1, text: trimmed))
            }
        }
        return result
    }

    private static func bestIngredientMatch(for line: String, in base: [Ingredient], excluding excluded: Set<UUID>) -> Ingredient? {
        var best: Ingredient?
        var bestScore: Double = 0
        for ing in base where !excluded.contains(ing.id) {
            let baseLine = ing.quantity.isEmpty ? ing.name : "\(ing.quantity) \(ing.name)"
            let score = textSimilarity(line, baseLine)
            if score > bestScore {
                bestScore = score
                best = ing
            }
        }
        return bestScore >= similarityThreshold ? best : nil
    }

    private static func bestStepMatch(for text: String, in base: [Step], excluding excluded: Set<UUID>) -> Step? {
        var best: Step?
        var bestScore: Double = 0
        for step in base where !excluded.contains(step.id) {
            let score = textSimilarity(text, step.text)
            if score > bestScore {
                bestScore = score
                best = step
            }
        }
        return bestScore >= similarityThreshold ? best : nil
    }

    /// Jaccard similarity. Character-level for CJK input, word-level
    /// otherwise. Returns 0…1.
    static func textSimilarity(_ a: String, _ b: String) -> Double {
        let aLower = a.lowercased()
        let bLower = b.lowercased()
        if LanguageHeuristics.containsCJK(a) || LanguageHeuristics.containsCJK(b) {
            let aChars = Set(aLower)
            let bChars = Set(bLower)
            let intersection = aChars.intersection(bChars).count
            let union = aChars.union(bChars).count
            return union > 0 ? Double(intersection) / Double(union) : 0
        }
        let aWords = Set(aLower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let bWords = Set(bLower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let intersection = aWords.intersection(bWords).count
        let union = aWords.union(bWords).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}
