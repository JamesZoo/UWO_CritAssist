import Foundation

struct MockRecipeGenerator: RecipeGenerator {
    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        try? await Task.sleep(nanoseconds: 200_000_000)
        let key = dishName.lowercased()
        if key.contains("宫爆") || key.contains("kung pao") || key.contains("gong bao") {
            return kungPaoSeed(name: dishName)
        }
        if key.contains("麻婆") || key.contains("mapo") {
            return mapoSeed(name: dishName)
        }
        throw RecipeGeneratorError.unknownDish(dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try? await Task.sleep(nanoseconds: 250_000_000)
        let host = url.host() ?? "external source"
        let name = description?.isEmpty == false ? description! : "Recipe from \(host)"
        return InitialRecipeDraft(
            name: name,
            summary: "Imported from \(url.absoluteString). Mock parser produced a placeholder; the real backend will extract structured fields.",
            ingredients: [
                Ingredient(name: "Main ingredient (from URL)", quantity: "as listed")
            ],
            steps: [
                Step(index: 1, text: "Follow source instructions; see \(url.absoluteString).")
            ],
            referenceStyle: description ?? "URL-imported"
        )
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        try? await Task.sleep(nanoseconds: 250_000_000)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RecipeGeneratorError.parsingFailed("empty text") }
        let (ingredients, steps) = MockRecipeGenerator.basicParse(text: trimmed)
        let name = description?.isEmpty == false ? description! : "User recipe"
        return InitialRecipeDraft(
            name: name,
            summary: description ?? "Imported from pasted text. Mock parser made a best-effort split into ingredients and steps.",
            ingredients: ingredients,
            steps: steps,
            referenceStyle: description.flatMap { $0.isEmpty ? nil : $0 } ?? "User-provided"
        )
    }

    static func basicParse(text: String) -> (ingredients: [Ingredient], steps: [Step]) {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var section: String? = nil
        var ingredients: [Ingredient] = []
        var steps: [Step] = []
        for raw in lines {
            let lower = raw.lowercased()
            if lower.hasPrefix("ingredients") {
                section = "ingredients"
                continue
            }
            if lower.hasPrefix("steps") || lower.hasPrefix("directions") || lower.hasPrefix("instructions") || lower.hasPrefix("method") {
                section = "steps"
                continue
            }
            if section == "ingredients" {
                let cleaned = raw.replacing(/^[-*•]\s*/, with: "")
                ingredients.append(Ingredient(name: cleaned, quantity: ""))
            } else if section == "steps" {
                let cleaned = raw.replacing(/^\d+[.)]\s*/, with: "")
                steps.append(Step(index: steps.count + 1, text: cleaned))
            } else {
                // No section header seen yet: heuristic — bullet => ingredient, numbered => step
                if raw.range(of: #"^[-*•]"#, options: .regularExpression) != nil {
                    let cleaned = raw.replacing(/^[-*•]\s*/, with: "")
                    ingredients.append(Ingredient(name: cleaned, quantity: ""))
                } else if raw.range(of: #"^\d+[.)]"#, options: .regularExpression) != nil {
                    let cleaned = raw.replacing(/^\d+[.)]\s*/, with: "")
                    steps.append(Step(index: steps.count + 1, text: cleaned))
                } else {
                    steps.append(Step(index: steps.count + 1, text: raw))
                }
            }
        }
        if steps.isEmpty && !ingredients.isEmpty {
            steps.append(Step(index: 1, text: "Combine and cook as desired (no method provided)."))
        }
        return (ingredients, steps)
    }

    private func mapoSeed(name: String) -> InitialRecipeDraft {
        InitialRecipeDraft(
            name: name,
            summary: "Sichuan classic: silken tofu in a numbing, spicy doubanjiang-based sauce with minced meat.",
            ingredients: [
                Ingredient(name: "Silken tofu", quantity: "400 g"),
                Ingredient(name: "Pixian doubanjiang", quantity: "2 tbsp"),
                Ingredient(name: "Ground beef or pork", quantity: "100 g"),
                Ingredient(name: "Sichuan peppercorns", quantity: "1 tsp"),
                Ingredient(name: "Scallions", quantity: "2")
            ],
            steps: [
                Step(index: 1, text: "Cube tofu and blanch in salted water; drain."),
                Step(index: 2, text: "Brown ground meat; add doubanjiang and fry until oil reddens."),
                Step(index: 3, text: "Add stock and tofu; simmer gently; thicken with cornstarch slurry."),
                Step(index: 4, text: "Top with toasted ground Sichuan pepper and scallions.")
            ],
            referenceStyle: "Sichuan classic"
        )
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

}

struct MockRecipeRefiner: RecipeRefiner {
    func resetContext(for recipeID: UUID) async {
        // Mock has no per-recipe state to reset.
    }

    func refine(
        recipeID: UUID,
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
    func branch(from baseRevision: Revision, baseRecipeName: String, directive: String) async throws -> VariationDraft {
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
