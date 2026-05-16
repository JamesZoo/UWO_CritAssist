import Foundation

struct MockRecipeGenerator: RecipeGenerator {
    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        try? await Task.sleep(nanoseconds: 200_000_000)
        let key = dishName.lowercased()
        if key.contains("宫爆") || key.contains("kung pao") || key.contains("gong bao") {
            return kungPaoSeed(name: dishName)
        }
        return genericSeed(name: dishName)
    }

    private func kungPaoSeed(name: String) -> InitialRecipeDraft {
        InitialRecipeDraft(
            name: name,
            summary: "Classic Sichuan stir-fry: diced chicken with peanuts in a sweet-sour-spicy sauce.",
            ingredients: [
                Ingredient(name: "Boneless chicken thigh", quantity: "300 g"),
                Ingredient(name: "Roasted peanuts", quantity: "60 g"),
                Ingredient(name: "Dried red chilies", quantity: "8"),
                Ingredient(name: "Sichuan peppercorns", quantity: "1 tsp"),
                Ingredient(name: "Scallion whites", quantity: "3"),
                Ingredient(name: "Chinkiang vinegar", quantity: "2 tbsp"),
                Ingredient(name: "Light soy sauce", quantity: "1 tbsp"),
                Ingredient(name: "Sugar", quantity: "1 tbsp"),
                Ingredient(name: "Cornstarch", quantity: "1 tsp")
            ],
            steps: [
                Step(index: 1, text: "Dice chicken and toss with a pinch of salt, 1 tsp cornstarch, and 1 tsp soy sauce.", technique: "velveting"),
                Step(index: 2, text: "Mix sauce: vinegar, soy, sugar, and 2 tbsp water."),
                Step(index: 3, text: "Heat oil; sizzle chilies and peppercorns until fragrant."),
                Step(index: 4, text: "Add chicken; stir-fry over high heat until just cooked."),
                Step(index: 5, text: "Add scallions and peanuts; pour in sauce and toss to glaze.")
            ],
            referenceStyle: "Sichuan home-style"
        )
    }

    private func genericSeed(name: String) -> InitialRecipeDraft {
        InitialRecipeDraft(
            name: name,
            summary: "A draft recipe for \(name), synthesized from common preparations.",
            ingredients: [
                Ingredient(name: "Main protein or vegetable", quantity: "300 g"),
                Ingredient(name: "Aromatics", quantity: "2 tbsp"),
                Ingredient(name: "Seasoning sauce", quantity: "2 tbsp")
            ],
            steps: [
                Step(index: 1, text: "Prep and season the main ingredient."),
                Step(index: 2, text: "Sear or sauté over medium-high heat."),
                Step(index: 3, text: "Add aromatics and seasoning; finish and serve.")
            ],
            referenceStyle: "Generic"
        )
    }
}

struct MockRecipeRefiner: RecipeRefiner {
    func refine(
        previousRevision: Revision,
        newFeedback: [Feedback],
        feedbackHistory: [Feedback]
    ) async throws -> RefinedRevisionDraft {
        try? await Task.sleep(nanoseconds: 250_000_000)
        var ingredients = previousRevision.ingredients
        var steps = previousRevision.steps
        var changes: [Change] = []
        var rationaleBits: [String] = []

        for fb in newFeedback {
            let f = fb.text.lowercased()
            if f.contains("sour") || f.contains("vinegar") {
                if let i = ingredients.firstIndex(where: { $0.name.lowercased().contains("vinegar") }) {
                    let before = ingredients[i]
                    ingredients[i].quantity = "1 tbsp"
                    changes.append(Change(kind: .ingredientEdited, summary: "Reduced \(before.name) to 1 tbsp", feedbackID: fb.id, targetIngredientID: before.id))
                    rationaleBits.append("toned down acidity")
                }
            }
            if f.contains("salty") {
                if let i = ingredients.firstIndex(where: { $0.name.lowercased().contains("soy") }) {
                    let before = ingredients[i]
                    ingredients[i].quantity = "1 tsp"
                    changes.append(Change(kind: .ingredientEdited, summary: "Reduced \(before.name) to 1 tsp", feedbackID: fb.id, targetIngredientID: before.id))
                    rationaleBits.append("less salt")
                }
            }
            if f.contains("chewy") || f.contains("tough") || f.contains("blood") || f.contains("smell") || f.contains("fishy") {
                let soak = Step(index: 1, text: "Soak diced chicken in cold water for 15 min, drain and pat dry.", technique: "blood-purge")
                for j in steps.indices { steps[j].index += 1 }
                steps.insert(soak, at: 0)
                changes.append(Change(kind: .stepAdded, summary: "Added 15-min cold-water soak before marinating", feedbackID: fb.id, targetStepID: soak.id))
                if !ingredients.contains(where: { $0.name.lowercased().contains("shaoxing") }) {
                    let wine = Ingredient(name: "Shaoxing wine", quantity: "1 tsp")
                    ingredients.append(wine)
                    changes.append(Change(kind: .ingredientAdded, summary: "Added Shaoxing wine to marinade", feedbackID: fb.id, targetIngredientID: wine.id))
                }
                if !ingredients.contains(where: { $0.name.lowercased().contains("ginger") }) {
                    let ginger = Ingredient(name: "Grated ginger", quantity: "1 tsp")
                    ingredients.append(ginger)
                    changes.append(Change(kind: .ingredientAdded, summary: "Added grated ginger to marinade", feedbackID: fb.id, targetIngredientID: ginger.id))
                }
                rationaleBits.append("addressed protein texture and odor")
            }
            if f.contains("spicy") || f.contains("hot") || (f.contains("too") && f.contains("chili")) {
                if let i = ingredients.firstIndex(where: { $0.name.lowercased().contains("chili") }) {
                    let before = ingredients[i]
                    ingredients[i].quantity = "4"
                    changes.append(Change(kind: .ingredientEdited, summary: "Halved dried chilies", feedbackID: fb.id, targetIngredientID: before.id))
                    rationaleBits.append("dialed back heat")
                }
            }
        }

        if changes.isEmpty {
            let cosmetic = Change(kind: .stepEdited, summary: "Refined timing wording", feedbackID: newFeedback.first?.id)
            changes.append(cosmetic)
            rationaleBits.append("minor tweaks")
        }

        return RefinedRevisionDraft(
            ingredients: ingredients,
            steps: steps,
            referenceStyle: previousRevision.referenceStyle,
            rationale: "Mock refinement: " + rationaleBits.joined(separator: ", ") + ".",
            changes: changes,
            addressedFeedbackIDs: newFeedback.map(\.id)
        )
    }
}

struct MockVariationBrancher: VariationBrancher {
    func branch(from baseRevision: Revision, directive: String) async throws -> VariationDraft {
        try? await Task.sleep(nanoseconds: 200_000_000)
        var ingredients = baseRevision.ingredients
        var changes: [Change] = []
        let lower = directive.lowercased()
        let name: String

        if lower.contains("no chili") || lower.contains("non chili") || lower.contains("without chili") || lower.contains("不辣") {
            name = "No-chili version"
            ingredients.removeAll { $0.name.lowercased().contains("chili") }
            changes.append(Change(kind: .ingredientRemoved, summary: "Removed dried chilies"))
        } else if lower.contains("chili") || lower.contains("spicy") || lower.contains("辣") {
            name = "Extra-chili version"
            if let i = ingredients.firstIndex(where: { $0.name.lowercased().contains("chili") }) {
                ingredients[i].quantity = "16"
                changes.append(Change(kind: .ingredientEdited, summary: "Doubled dried chilies"))
            }
        } else {
            name = directive.isEmpty ? "Variation" : directive.prefix(40).description
        }

        return VariationDraft(
            name: name,
            ingredients: ingredients,
            steps: baseRevision.steps,
            referenceStyle: baseRevision.referenceStyle,
            rationale: "Mock variation per directive: \(directive)",
            changes: changes
        )
    }
}

struct MockRecipeFinalizer: RecipeFinalizer {
    func finalize(recipe: Recipe) async throws -> RecipeAnalysis {
        try? await Task.sleep(nanoseconds: 150_000_000)
        let bestBase = BestRevisionPicker.bestRevision(for: recipe)
        var variationBest: [UUID: UUID] = [:]
        for v in recipe.variations {
            if let best = BestRevisionPicker.bestRevision(for: v) {
                variationBest[v.id] = best.id
            }
        }
        let doc = buildDocument(recipe: recipe, bestBaseID: bestBase?.id, variationBest: variationBest)
        return RecipeAnalysis(
            journeySummary: "Mock summary: \(recipe.revisions.count) base revisions across \(recipe.feedback.count) feedback notes; \(recipe.variations.count) variations.",
            baseBestRevisionID: bestBase?.id ?? UUID(),
            variationBestRevisionIDs: variationBest,
            finalDocument: doc
        )
    }

    private func buildDocument(recipe: Recipe, bestBaseID: UUID?, variationBest: [UUID: UUID]) -> String {
        var out = "# \(recipe.name)\n\n"
        if let id = bestBaseID, let r = recipe.revisions.first(where: { $0.id == id }) {
            out += formatRevision(r) + "\n"
        }
        for v in recipe.variations {
            out += "## \(v.name)\n\n"
            if let id = variationBest[v.id], let r = v.revisions.first(where: { $0.id == id }) {
                out += formatRevision(r) + "\n"
            }
        }
        return out
    }

    private func formatRevision(_ r: Revision) -> String {
        var s = "Ingredients:\n"
        for i in r.ingredients { s += "- \(i.quantity) \(i.name)\n" }
        s += "\nSteps:\n"
        for st in r.steps { s += "\(st.index). \(st.text)\n" }
        return s
    }
}

struct MockRecipeImageService: RecipeImageService {
    func fetchImage(for dishName: String) async throws -> RecipeImageResult? {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return RecipeImageResult(
            imageURL: URL(string: "https://example.invalid/mock-thumbnail.jpg")!,
            attribution: ImageAttribution(
                sourceName: "Mock source",
                pageURL: nil,
                author: "Mock author",
                licenseName: "Public domain (mock)",
                licenseURL: nil
            )
        )
    }
}
