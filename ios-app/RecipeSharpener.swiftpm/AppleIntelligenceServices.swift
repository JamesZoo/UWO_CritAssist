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
