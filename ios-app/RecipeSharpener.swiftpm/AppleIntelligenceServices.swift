import Foundation
import FoundationModels

// MARK: - Availability

enum AppleIntelligence {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }
}

// MARK: - Generator output schema

@Generable
struct GeneratedRecipeContent {
    @Guide(description: "Dish name in the same language as the user's input. Preserve CJK characters when given.")
    var name: String

    @Guide(description: "One- to two-sentence description of the dish.")
    var summary: String

    @Guide(description: "Style or region reference like 'Sichuan home-style' or 'Cantonese'. Empty string if no notable style.")
    var referenceStyle: String

    @Guide(description: "Ingredient lines that each include a measurable quantity and unit, e.g. '300 g pork kidney' or '2 tbsp Shaoxing wine'.")
    var ingredients: [String]

    @Guide(description: "Ordered preparation steps as concise imperative sentences.")
    var steps: [String]
}

extension GeneratedRecipeContent {
    func toDraft(originalName: String) -> InitialRecipeDraft {
        InitialRecipeDraft(
            name: name.isEmpty ? originalName : name,
            summary: summary,
            ingredients: ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Ingredient(name: $0, quantity: "") },
            steps: steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { Step(index: $0.offset + 1, text: $0.element) },
            referenceStyle: referenceStyle.isEmpty ? nil : referenceStyle
        )
    }
}

// MARK: - Refiner output schema

@Generable
struct GeneratedChange {
    @Guide(description: "Kind of change. Must be exactly one of: stepAdded, stepRemoved, stepEdited, ingredientAdded, ingredientRemoved, ingredientEdited, techniqueChanged.")
    var kind: String

    @Guide(description: "Plain-language summary of this single change, e.g. 'Reduced Chinkiang vinegar from 2 tbsp to 1 tbsp' or 'Added a 15-minute cold-water soak before marinating'.")
    var summary: String
}

@Generable
struct GeneratedRefinement {
    @Guide(description: "Diagnosis: explain why the user likely got this feedback. Reason about cause and effect — what specific aspect of the recipe most plausibly produced the user's complaint.")
    var diagnosis: String

    @Guide(description: "Rationale: explain what is being changed and why it should address the feedback. Connect each change back to the diagnosis.")
    var rationale: String

    @Guide(description: "Style or region reference like 'Sichuan home-style'. Empty string if unchanged.")
    var referenceStyle: String

    @Guide(description: "Updated full ingredient list with measurable quantities. Each line should be self-contained, e.g. '1 tbsp Chinkiang vinegar'.")
    var ingredients: [String]

    @Guide(description: "Updated full ordered preparation steps as imperative sentences.")
    var steps: [String]

    @Guide(description: "List of the specific changes made in this refinement, one entry per change. Each change carries its kind and a short summary.")
    var changes: [GeneratedChange]
}

extension GeneratedRefinement {
    func toDraft(addressedFeedback: [Feedback]) -> RefinedRevisionDraft {
        let feedbackID = addressedFeedback.first?.id
        let changeRecords: [Change] = changes.map { gc in
            let normalized = gc.kind.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = ChangeKind(rawValue: normalized) ?? .stepEdited
            return Change(
                kind: kind,
                summary: gc.summary,
                feedbackID: feedbackID
            )
        }
        let combined: String
        if diagnosis.isEmpty {
            combined = rationale
        } else if rationale.isEmpty {
            combined = diagnosis
        } else {
            combined = "\(diagnosis)\n\n\(rationale)"
        }
        return RefinedRevisionDraft(
            ingredients: ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Ingredient(name: $0, quantity: "") },
            steps: steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { Step(index: $0.offset + 1, text: $0.element) },
            referenceStyle: referenceStyle.isEmpty ? nil : referenceStyle,
            rationale: combined,
            changes: changeRecords,
            addressedFeedbackIDs: addressedFeedback.map(\.id)
        )
    }
}

// MARK: - Generator

struct AppleIntelligenceRecipeGenerator: RecipeGenerator {
    private static let dishInstructions = """
    You are an experienced cook. Given a dish name in any language (including \
    Chinese, Japanese, Korean, French, etc.), produce a starter recipe drawn \
    from common public preparations of that dish. Be accurate and culturally \
    appropriate. If the dish has a regional style, note it. Ingredients must \
    include measurable quantities. Steps must be ordered, actionable, and \
    concise. Keep the dish name in the original language as the user wrote it.
    """

    private static let parseInstructions = """
    You parse a user-pasted recipe — which may be in any language and may \
    be noisy with ads, navigation links, or unrelated commentary — into \
    clean structured form. Extract the dish name, a one-line summary, \
    ingredients with measurable quantities, and ordered preparation steps. \
    Ignore non-recipe content. If the user provided an "expected dish" \
    description, use it to disambiguate ambiguous text.
    """

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: Self.dishInstructions)
        let response = try await session.respond(
            to: "Create a starter recipe for the dish: \(dishName)",
            generating: GeneratedRecipeContent.self
        )
        return response.content.toDraft(originalName: dishName)
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        // URL fetching is handled by WebRecipeExtractor in DefaultRecipeGenerator;
        // AI cleanup of raw HTML is a separate path that hasn't landed yet.
        throw RecipeGeneratorError.unsupportedInput
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: Self.parseInstructions)
        let prompt: String
        if let description, !description.isEmpty {
            prompt = "Expected dish: \(description)\n\nRecipe text:\n\(text)"
        } else {
            prompt = "Recipe text:\n\(text)"
        }
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedRecipeContent.self
        )
        return response.content.toDraft(originalName: description ?? "User recipe")
    }
}

// MARK: - Refiner

struct AppleIntelligenceRecipeRefiner: RecipeRefiner {
    private static let instructions = """
    You help iterate on a recipe based on user feedback. Each round you:
    1. Diagnose: reason about why the user got this feedback. Be specific \
       about cause and effect — e.g. "soup too sour" likely means too much \
       acid, acid added too early, or the wrong acid type; "meat is chewy \
       with a blood smell" likely means missing velveting / cold-water soak / \
       no Shaoxing wine in the marinade.
    2. Propose targeted changes that address the diagnosis. Make minimal, \
       focused edits — don't rewrite the whole recipe. Common kinds of \
       change: adjust an ingredient quantity, swap an ingredient, insert or \
       remove a prep step, change a technique.
    3. Output the updated full recipe (ingredients + steps), a rationale \
       linking each change to the diagnosis, and a list of the specific \
       changes you made.
    Keep the recipe in the same language as the original. Ingredient \
    quantities must be measurable. Each "kind" field in your changes list \
    must be exactly one of: stepAdded, stepRemoved, stepEdited, \
    ingredientAdded, ingredientRemoved, ingredientEdited, techniqueChanged.
    """

    func refine(
        previousRevision: Revision,
        newFeedback: [Feedback],
        feedbackHistory: [Feedback]
    ) async throws -> RefinedRevisionDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = buildPrompt(prev: previousRevision, newFeedback: newFeedback, history: feedbackHistory)
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedRefinement.self
        )
        return response.content.toDraft(addressedFeedback: newFeedback)
    }

    private func buildPrompt(prev: Revision, newFeedback: [Feedback], history: [Feedback]) -> String {
        var s = "Current recipe (revision \(prev.index)):\n\nIngredients:\n"
        for ing in prev.ingredients {
            let qty = ing.quantity.isEmpty ? "" : ing.quantity + " "
            s += "- \(qty)\(ing.name)\n"
        }
        s += "\nSteps:\n"
        for st in prev.steps {
            s += "\(st.index). \(st.text)\n"
        }
        s += "\nNew feedback to address:\n"
        for fb in newFeedback {
            s += "- \(fb.text)\n"
        }
        if !history.isEmpty {
            s += "\nEarlier feedback (already addressed in prior revisions, for context):\n"
            for fb in history {
                s += "- \(fb.text)\n"
            }
        }
        return s
    }
}

// MARK: - Variation brancher

@Generable
struct GeneratedVariation {
    @Guide(description: "Short variation name based on the directive, e.g. 'Chili version' or 'Vegetarian'.")
    var name: String

    @Guide(description: "Rationale: explain how this variation differs from the base and why these changes hold together culinarily.")
    var rationale: String

    @Guide(description: "Style or region reference. Empty if unchanged from base.")
    var referenceStyle: String

    @Guide(description: "Full ingredient list for the variation, with measurable quantities.")
    var ingredients: [String]

    @Guide(description: "Full ordered preparation steps for the variation.")
    var steps: [String]

    @Guide(description: "List of specific changes from the base recipe. Each change's kind must be exactly one of: stepAdded, stepRemoved, stepEdited, ingredientAdded, ingredientRemoved, ingredientEdited, techniqueChanged.")
    var changes: [GeneratedChange]
}

extension GeneratedVariation {
    func toDraft() -> VariationDraft {
        VariationDraft(
            name: name,
            ingredients: ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Ingredient(name: $0, quantity: "") },
            steps: steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { Step(index: $0.offset + 1, text: $0.element) },
            referenceStyle: referenceStyle.isEmpty ? nil : referenceStyle,
            rationale: rationale,
            changes: changes.map { gc in
                let kind = ChangeKind(rawValue: gc.kind.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .stepEdited
                return Change(kind: kind, summary: gc.summary, feedbackID: nil)
            }
        )
    }
}

struct AppleIntelligenceVariationBrancher: VariationBrancher {
    private static let instructions = """
    You create a variation of an existing recipe based on a user directive \
    (for example: "without chili", "vegetarian version", "extra spicy", \
    "lower sodium"). Start from the base recipe (ingredients + steps) and \
    produce a variation that:
    - Honors the directive accurately
    - Keeps the dish's character intact where possible
    - Adjusts ingredients and steps so the variation works culinarily — e.g. \
      if removing chili from a Sichuan dish, consider reducing other heat \
      sources or compensating elsewhere to keep balance
    Output the variation name, full ingredient list, full ordered steps, a \
    rationale, and a list of the specific changes you made versus the base. \
    Keep the recipe in the same language as the base. Each change's kind \
    must be one of: stepAdded, stepRemoved, stepEdited, ingredientAdded, \
    ingredientRemoved, ingredientEdited, techniqueChanged.
    """

    func branch(from baseRevision: Revision, directive: String) async throws -> VariationDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = buildPrompt(base: baseRevision, directive: directive)
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedVariation.self
        )
        return response.content.toDraft()
    }

    private func buildPrompt(base: Revision, directive: String) -> String {
        var s = "Base recipe:\n\nIngredients:\n"
        for ing in base.ingredients {
            let q = ing.quantity.isEmpty ? "" : ing.quantity + " "
            s += "- \(q)\(ing.name)\n"
        }
        s += "\nSteps:\n"
        for st in base.steps {
            s += "\(st.index). \(st.text)\n"
        }
        s += "\nDirective for variation: \(directive)"
        return s
    }
}

// MARK: - Finalizer

@Generable
struct GeneratedAnalysis {
    @Guide(description: "Journey summary: narrative paragraph (or two) telling the story of how this recipe evolved across revisions — what was tried, what feedback drove which improvements, what was learned.")
    var journeySummary: String

    @Guide(description: "Final polished document: a ready-to-cook write-up with the best-of-base recipe and, after that, each variation as its own section. Use markdown-style headers (##), bold for section names like Ingredients and Steps, and numbered steps. Keep the language consistent with the original recipe.")
    var finalDocument: String
}

struct AppleIntelligenceRecipeFinalizer: RecipeFinalizer {
    private static let instructions = """
    You write the final, polished write-up of a recipe that has gone \
    through iterative refinement based on user feedback. You receive:
    - The recipe name
    - All revisions of the base with their rationales and the changes \
      they made
    - All user feedback against the base
    - For each variation: its directive, its revisions, and its feedback
    - The "best" revision of the base and the best revision of each \
      variation, already chosen for you
    Output two things:
    1. journeySummary — a narrative of how the recipe evolved: what was \
       tried, what feedback drove which improvements, what was learned. \
       One to three short paragraphs.
    2. finalDocument — a polished, ready-to-cook document. Start with the \
       best base recipe (ingredients then numbered steps). Then add each \
       variation as its own section (## Variation name). Use markdown-style \
       headers and bullet lists. Keep the language consistent with the \
       original recipe (preserve CJK if the source was CJK).
    """

    func finalize(recipe: Recipe) async throws -> RecipeAnalysis {
        let bestBase = BestRevisionPicker.bestRevision(for: recipe)
        var variationBest: [UUID: UUID] = [:]
        var variationBestRevisions: [(Variation, Revision)] = []
        for v in recipe.variations {
            if let best = BestRevisionPicker.bestRevision(for: v) {
                variationBest[v.id] = best.id
                variationBestRevisions.append((v, best))
            }
        }

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = buildPrompt(recipe: recipe, bestBase: bestBase, variationBestRevisions: variationBestRevisions)
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedAnalysis.self
        )
        let content = response.content
        return RecipeAnalysis(
            journeySummary: content.journeySummary,
            baseBestRevisionID: bestBase?.id ?? UUID(),
            variationBestRevisionIDs: variationBest,
            finalDocument: content.finalDocument
        )
    }

    private func buildPrompt(recipe: Recipe, bestBase: Revision?, variationBestRevisions: [(Variation, Revision)]) -> String {
        var s = "Recipe name: \(recipe.name)\n\n"
        s += "Base recipe history:\n"
        for r in recipe.revisions {
            let marker = (r.id == bestBase?.id) ? " ← BEST" : ""
            s += "  Revision \(r.index)\(marker):\n"
            if !r.rationale.isEmpty {
                s += "    Rationale: \(r.rationale)\n"
            }
            for c in r.changes {
                s += "    - \(c.kind.rawValue): \(c.summary)\n"
            }
        }
        if let best = bestBase {
            s += "\nBest base ingredients:\n"
            for i in best.ingredients {
                let q = i.quantity.isEmpty ? "" : i.quantity + " "
                s += "- \(q)\(i.name)\n"
            }
            s += "Best base steps:\n"
            for st in best.steps {
                s += "\(st.index). \(st.text)\n"
            }
        }
        if !recipe.feedback.isEmpty {
            s += "\nBase feedback received:\n"
            for fb in recipe.feedback {
                let rating = fb.rating.map { " [\($0)/5]" } ?? ""
                s += "- \(fb.text)\(rating)\n"
            }
        }
        for (v, best) in variationBestRevisions {
            s += "\nVariation: \(v.name) (directive: \(v.directive))\n"
            s += "  Ingredients:\n"
            for i in best.ingredients {
                let q = i.quantity.isEmpty ? "" : i.quantity + " "
                s += "  - \(q)\(i.name)\n"
            }
            s += "  Steps:\n"
            for st in best.steps {
                s += "  \(st.index). \(st.text)\n"
            }
            if !v.feedback.isEmpty {
                s += "  Variation feedback:\n"
                for fb in v.feedback {
                    s += "  - \(fb.text)\n"
                }
            }
        }
        return s
    }
}
