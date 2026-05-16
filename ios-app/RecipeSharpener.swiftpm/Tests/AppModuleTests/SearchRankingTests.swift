import Testing
import Foundation
@testable import AppModule

@Suite("SearchRanking")
struct SearchRankingTests {

    private func recipe(
        name: String,
        summary: String = "",
        ingredients: [String] = [],
        steps: [String] = [],
        variations: [String] = [],
        created: Date = Date()
    ) -> Recipe {
        let ings = ingredients.map { Ingredient(name: $0, quantity: "1") }
        let stps = steps.enumerated().map { Step(index: $0.offset + 1, text: $0.element) }
        let rev = Revision(index: 1, ingredients: ings, steps: stps)
        let vars = variations.map { Variation(name: $0, directive: "") }
        return Recipe(name: name, summary: summary, createdAt: created, revisions: [rev], variations: vars)
    }

    @Test("empty query returns all recipes in original order")
    func emptyQueryReturnsAll() {
        let a = recipe(name: "A")
        let b = recipe(name: "B")
        let result = SearchRanking.rank([a, b], for: "  ")
        #expect(result.map(\.name) == ["A", "B"])
    }

    @Test("name match outranks summary match")
    func nameOverSummary() {
        let nameMatch = recipe(name: "Kung Pao Chicken", summary: "spicy")
        let summaryMatch = recipe(name: "Salad", summary: "kung pao style dressing")
        let result = SearchRanking.rank([summaryMatch, nameMatch], for: "kung pao")
        #expect(result.first?.name == "Kung Pao Chicken")
    }

    @Test("ingredient match outranks step match")
    func ingredientOverStep() {
        let ingMatch = recipe(name: "Dish A", ingredients: ["Shaoxing wine"])
        let stepMatch = recipe(name: "Dish B", steps: ["splash with shaoxing wine to finish"])
        let result = SearchRanking.rank([stepMatch, ingMatch], for: "shaoxing")
        #expect(result.first?.name == "Dish A")
    }

    @Test("recipes with no match are filtered out")
    func filtersUnmatched() {
        let yes = recipe(name: "Mapo Tofu")
        let no = recipe(name: "Spaghetti")
        let result = SearchRanking.rank([no, yes], for: "tofu")
        #expect(result.map(\.name) == ["Mapo Tofu"])
    }

    @Test("CJK queries match CJK names")
    func cjkSearch() {
        let dish = recipe(name: "宫爆鸡丁")
        let result = SearchRanking.rank([dish], for: "宫爆")
        #expect(result.first?.name == "宫爆鸡丁")
    }

    @Test("case-insensitive matching")
    func caseInsensitive() {
        let dish = recipe(name: "Kung Pao Chicken")
        let result = SearchRanking.rank([dish], for: "CHICKEN")
        #expect(result.count == 1)
    }

    @Test("tie on score breaks by recency (newer first)")
    func ageTieBreak() {
        let now = Date()
        let older = recipe(name: "Kung Pao", created: now.addingTimeInterval(-1000))
        let newer = recipe(name: "Kung Pao", created: now)
        let result = SearchRanking.rank([older, newer], for: "kung pao")
        #expect(result.first?.createdAt == newer.createdAt)
    }

    @Test("variation name match contributes to score")
    func variationContributes() {
        let dish = recipe(name: "Hotpot", variations: ["Spicy chili broth"])
        let result = SearchRanking.rank([dish], for: "chili")
        #expect(result.count == 1)
    }
}
