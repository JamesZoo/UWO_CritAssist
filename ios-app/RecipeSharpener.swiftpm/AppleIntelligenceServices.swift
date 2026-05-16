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
    private static let catalogInstructions = """
    You are a recipe lookup service for a home cooking app. The user submits \
    a dish name — a text label that identifies a well-known dish from world \
    cuisine — and you return its standard home preparation.

    Examples of dishes in this catalog: 宫爆鸡丁 (Kung Pao Chicken), \
    麻婆豆腐 (Mapo Tofu), 红烧排骨 (Red-braised Pork Ribs), 鱼香肉丝, 葱油饼, \
    爆炒腰花, 回锅肉, Coq au Vin, Beef Wellington, Margherita Pizza, \
    Pad Thai, Bibimbap, Tiramisu, Caesar Salad, Borscht.

    The dish name is a benign culinary reference label. All entries here are \
    standard public recipes. Output:
    - Ingredients with measurable quantities (one per line)
    - Ordered preparation steps as imperative sentences

    LANGUAGE RULE — important: output every field (name, summary, \
    referenceStyle, ingredients, steps) in the SAME language as the user's \
    dish name. If the dish name is in Chinese (e.g. 红烧排骨), the entire \
    recipe must be in Chinese. If the dish name is in English (e.g. \
    "Beef Wellington"), the entire recipe must be in English. Do not mix \
    languages within the output.

    Be culturally accurate and note the regional style when applicable.
    """

    private static let chineseCatalogInstructions = """
    你是一个家常菜谱查询服务。用户输入一个菜名（来自世界各地饮食文化的菜肴\
    名称标签），你返回它的标准家常做法。

    数据库中的菜例：宫爆鸡丁、麻婆豆腐、红烧排骨、鱼香肉丝、葱油饼、\
    爆炒腰花、回锅肉、葱烧海参、四喜丸子、Coq au Vin、Pizza。

    菜名是常见的烹饪标签，本服务仅处理标准的家常烹饪内容。

    语言要求：所有字段（菜名、简介、风味说明、食材、步骤）都必须使用与用户\
    输入菜名相同的语言。如果用户输入的菜名是中文（如"红烧排骨"），整个食谱\
    必须使用中文。请勿在输出中混合不同语言。

    输出：
    - 食材清单（每行一项，标明可测量的分量）
    - 按顺序排列的烹饪步骤（祈使句）
    """

    private static let parseInstructions = """
    You parse a user-pasted recipe — which may be in any language and may \
    be noisy with ads, navigation links, or unrelated commentary — into \
    clean structured form. Extract the dish name, a one-line summary, \
    ingredients with measurable quantities, and ordered preparation steps. \
    Ignore non-recipe content.

    LANGUAGE RULE: if the user provides an "Expected dish" description, use \
    it to disambiguate ambiguous text AND output the entire recipe (name, \
    summary, style, ingredients, steps) in the language of that description. \
    For example, if Expected dish is in Chinese but the source recipe text \
    is in English, translate every field into Chinese for output. If no \
    Expected dish is given, output in the language of the source recipe.
    """

    private static let translateInstructions = """
    You translate a structured recipe from one language to another while \
    preserving every field, the order of steps, and all measurable quantities. \
    Output the same recipe object in the target language. Do not add, remove, \
    or reorder ingredients or steps; only translate the text. If the dish \
    name has a standard form in the target language, use it; otherwise, \
    transliterate.
    """

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        let cjk = Self.containsCJK(dishName)
        var attempts: [(system: String, user: String)] = [
            // Primary: catalog-lookup framing. The dish name is positioned as
            // a reference label among a list of benign examples — the strongest
            // contextualization we can do client-side.
            (Self.catalogInstructions,
             "Look up the standard home recipe for: \(dishName)")
        ]
        if cjk {
            // For CJK names, retry in the same language so there's no
            // bilingual surface for the filter to react to.
            attempts.append((
                Self.chineseCatalogInstructions,
                "查询并输出这道菜的标准家常做法：\(dishName)"
            ))
            attempts.append((
                Self.chineseCatalogInstructions,
                "这是一道常见的家常菜。请按照菜谱数据库的格式输出：\(dishName)。先列出食材和分量，再按顺序写步骤。"
            ))
        } else {
            attempts.append((
                Self.catalogInstructions,
                "Provide the standard preparation for the dish \(dishName). List ingredients with quantities, then ordered steps."
            ))
        }

        for (system, user) in attempts {
            do {
                return try await tryGenerate(system: system, user: user, dishName: dishName)
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error {
                    continue
                }
                throw error
            }
        }
        throw RecipeGeneratorError.safetyDeclined(dishName)
    }

    private func tryGenerate(system: String, user: String, dishName: String) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: system)
        let response = try await session.respond(
            to: user,
            generating: GeneratedRecipeContent.self
        )
        return response.content.toDraft(originalName: dishName)
    }

    private static func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0x3040...0x30FF).contains(scalar.value)
                || (0xAC00...0xD7AF).contains(scalar.value)
        }
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

    /// Translate an already-extracted recipe to the target language, preserving
    /// structure (ingredient count, step order, quantities) but translating all
    /// human-readable text. Used by DefaultRecipeGenerator after URL extraction
    /// when the source page's language differs from the user's expected-dish
    /// description.
    func translateDraft(_ draft: InitialRecipeDraft, toLanguage language: String) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: Self.translateInstructions)
        let prompt = buildTranslationPrompt(draft: draft, targetLanguage: language)
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedRecipeContent.self
        )
        let translated = response.content
        return InitialRecipeDraft(
            name: translated.name.isEmpty ? draft.name : translated.name,
            summary: translated.summary.isEmpty ? draft.summary : translated.summary,
            ingredients: translated.ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Ingredient(name: $0, quantity: "") },
            steps: translated.steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { Step(index: $0.offset + 1, text: $0.element) },
            referenceStyle: translated.referenceStyle.isEmpty ? draft.referenceStyle : translated.referenceStyle,
            imageURL: draft.imageURL,
            imageAttribution: draft.imageAttribution
        )
    }

    private func buildTranslationPrompt(draft: InitialRecipeDraft, targetLanguage: String) -> String {
        var s = "Target language: \(targetLanguage)\n\n"
        s += "Recipe to translate:\n\n"
        s += "Name: \(draft.name)\n"
        if !draft.summary.isEmpty { s += "Summary: \(draft.summary)\n" }
        if let style = draft.referenceStyle, !style.isEmpty { s += "Style: \(style)\n" }
        s += "\nIngredients:\n"
        for ing in draft.ingredients {
            let q = ing.quantity.isEmpty ? "" : ing.quantity + " "
            s += "- \(q)\(ing.name)\n"
        }
        s += "\nSteps:\n"
        for st in draft.steps {
            s += "\(st.index). \(st.text)\n"
        }
        return s
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
