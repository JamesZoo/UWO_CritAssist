import Foundation

enum SearchRanking {
    static let nameWeight = 10
    static let summaryWeight = 5
    static let ingredientWeight = 3
    static let stepWeight = 1
    static let variationNameWeight = 4

    static func rank(_ recipes: [Recipe], for query: String) -> [Recipe] {
        let q = normalize(query)
        guard !q.isEmpty else { return recipes }
        let scored = recipes.compactMap { recipe -> (Recipe, Int)? in
            let s = score(recipe: recipe, normalizedQuery: q)
            return s > 0 ? (recipe, s) : nil
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.createdAt > rhs.0.createdAt
            }
            .map(\.0)
    }

    static func score(recipe: Recipe, normalizedQuery q: String) -> Int {
        var s = 0
        if normalize(recipe.name).contains(q) { s += nameWeight }
        if normalize(recipe.summary).contains(q) { s += summaryWeight }
        if let current = recipe.currentRevision {
            for ing in current.ingredients where normalize(ing.name).contains(q) {
                s += ingredientWeight
            }
            for step in current.steps where normalize(step.text).contains(q) {
                s += stepWeight
            }
        }
        for variation in recipe.variations {
            if normalize(variation.name).contains(q) {
                s += variationNameWeight
            }
        }
        return s
    }

    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
