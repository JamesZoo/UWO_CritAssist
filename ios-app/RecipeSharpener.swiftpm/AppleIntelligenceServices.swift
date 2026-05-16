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

// MARK: - Image validation schema

@Generable
struct ImageMatchResult {
    @Guide(description: "True if the article's typical hero image would VISUALLY look similar enough to the named dish to serve as a reasonable representative photo. Reason about visual likelihood, not just topical identity: same food type, dominant ingredients on the plate, cooking method, color and texture profile, and how the dish is typically plated. Accept when (a) the article is the specific dish, (b) a standard alternate name / spelling, (c) a closely related dish in the same family with similar visual character (e.g. '红烧肉' for '广式红烧肉' — both are dark glossy braised pork belly cubes), or (d) the dish's main ingredient where the typical photo shows the ingredient prepared similarly (e.g. '猪蹄' for '东北酱猪蹄' — both depict braised pig trotters in dark sauce). Reject when the typical hero image is unpredictable or unrelated: broader cuisine categories like '广东菜' (Cantonese cuisine articles often hero dim sum or soup, not braised pork) or '川菜' (could be anything from mapo tofu to dry-fried beans), fundamentally different food types (a noodle article for a stir-fry dish), or non-food content. The judgment is about visual similarity to the named dish, not about whether the article is technically related.")
    var matches: Bool

    @Guide(description: "Brief reason that names what the article's typical photo likely looks like and how that compares visually to the named dish.")
    var reason: String
}

@Generable
struct AlternativeNames {
    @Guide(description: "Up to 3 alternative names or spellings of the dish for searching encyclopedias. Include: English translation, well-known alternates and romanizations, and the dish's main ingredient or key component as a fallback (e.g. for '东北酱猪蹄' include '猪蹄'; for '广式红烧肉' include '红烧肉'). Do not include broad cuisine categories like '川菜' or '广东菜'.")
    var terms: [String]
}

@Generable
struct TranslatedRefinementContent {
    @Guide(description: "Translated rationale paragraph in the target language.")
    var rationale: String

    @Guide(description: "Translated style / region reference. Empty string if none.")
    var referenceStyle: String

    @Guide(description: "Translated ingredient lines. Must have the same count and order as the input ingredients.")
    var ingredients: [String]

    @Guide(description: "Translated step text. Must have the same count and order as the input steps.")
    var steps: [String]

    @Guide(description: "Translated change summaries. Must have the same count and order as the input change list.")
    var changeSummaries: [String]
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
    dish name. Critically, draw on your knowledge of language-appropriate \
    culinary sources to do this naturally:
    - For dish names in Chinese (CJK), draw on Chinese-language cookbooks, \
      Chinese Wikipedia entries (zh.wikipedia.org), and Chinese recipe \
      websites. Write the entire recipe in Chinese.
    - For English names, draw on English cookbooks and English Wikipedia. \
      Write the recipe in English.
    - For other languages (French, Japanese, Korean, etc.), prefer that \
      language's sources and write the recipe in that language.
    Do not mix languages within the output.

    Be culturally accurate and note the regional style when applicable.
    """

    private static let chineseCatalogInstructions = """
    你是一个家常菜谱查询服务。用户输入一个菜名（来自世界各地饮食文化的菜肴\
    名称标签），你返回它的标准家常做法。

    数据库中的菜例：宫爆鸡丁、麻婆豆腐、红烧排骨、鱼香肉丝、葱油饼、\
    爆炒腰花、回锅肉、葱烧海参、四喜丸子、Coq au Vin、Pizza。

    菜名是常见的烹饪标签，本服务仅处理标准的家常烹饪内容。

    语言要求：所有字段（菜名、简介、风味说明、食材、步骤）都必须使用与用户\
    输入菜名相同的语言。请参考与该语言对应的烹饪资料来源——例如中文菜名\
    应参考中文菜谱、中文维基百科（zh.wikipedia.org）、中文烹饪网站——这样\
    输出自然会是中文。请勿在输出中混合不同语言。

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
    Draw on your knowledge of cooking sources in that language to phrase \
    the output naturally. For example, if Expected dish is in Chinese but \
    the source recipe text is in English, translate every field into \
    Chinese using vocabulary and phrasing that matches Chinese cookbooks. \
    If no Expected dish is given, output in the language of the source \
    recipe.
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
        let cjk = LanguageHeuristics.containsCJK(dishName)
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

        var generated: InitialRecipeDraft?
        for (system, user) in attempts {
            do {
                generated = try await tryGenerate(system: system, user: user, dishName: dishName)
                break
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error {
                    continue
                }
                throw error
            }
        }
        guard let draft = generated else {
            throw RecipeGeneratorError.safetyDeclined(dishName)
        }
        return try await enforceLanguage(draft: draft, referenceText: dishName)
    }

    private func tryGenerate(system: String, user: String, dishName: String) async throws -> InitialRecipeDraft {
        let session = LanguageModelSession(instructions: system)
        let response = try await session.respond(
            to: user,
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
        let draft = response.content.toDraft(originalName: description ?? "User recipe")
        let reference: String
        if let description, !description.isEmpty {
            reference = description
        } else {
            reference = draft.name
        }
        return try await enforceLanguage(draft: draft, referenceText: reference)
    }

    /// Inspect the body of the generated recipe and translate the entire
    /// draft into the language implied by `referenceText` (typically the
    /// user's dish name or expected-dish description). The model frequently
    /// ignores in-prompt language directives and produces English output
    /// for Chinese dish names; this is the post-generation safety net.
    func enforceLanguage(draft: InitialRecipeDraft, referenceText: String) async throws -> InitialRecipeDraft {
        let referenceCJK = LanguageHeuristics.containsCJK(referenceText)
        let summary = draft.summary
        let ingredients = draft.ingredients.map(\.name).joined(separator: " ")
        let steps = draft.steps.map(\.text).joined(separator: " ")
        let sample = "\(summary) \(ingredients) \(steps)"
        let sampleCJK = LanguageHeuristics.isMostlyCJK(sample)

        let targetLanguage: String?
        if referenceCJK && !sampleCJK {
            targetLanguage = "Chinese"
        } else if !referenceCJK && sampleCJK {
            targetLanguage = "English"
        } else {
            targetLanguage = nil
        }

        guard let target = targetLanguage else { return draft }

        do {
            return try await translateDraft(draft, toLanguage: target)
        } catch {
            // Best-effort: if translation fails, return the original draft
            // rather than failing the whole import.
            return draft
        }
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

    /// Decide whether a candidate source article is specifically about the
    /// named dish, used to reject mismatched Wikipedia photos (e.g. a 广东菜
    /// cuisine article serving a dim-sum thumbnail for 广式红烧肉).
    func validateImageMatch(articleTitle: String, dishName: String) async throws -> Bool {
        let session = LanguageModelSession(instructions: """
        You judge whether a Wikipedia article's typical hero photo would VISUALLY \
        look like a specific dish. This is a visual-similarity question, not a \
        topical identity question. Reason about what the article's typical photo \
        most likely shows, then compare that mental image to the named dish: \
        same food type? Same dominant ingredients on the plate? Similar cooking \
        method, color, texture, plating?

        Accept (matches=true) when the typical hero photo would plausibly pass \
        as the named dish — exact match, close family member with same visual \
        character (e.g. 红烧肉 article for 广式红烧肉 both look like dark glossy \
        braised pork cubes), or main-ingredient article where the typical photo \
        shows that ingredient prepared similarly to the dish (e.g. 猪蹄 article \
        for 东北酱猪蹄, both depict braised pig trotters in dark sauce).

        Reject (matches=false) when the typical hero photo is unpredictable or \
        visually unrelated — broad cuisine categories (广东菜, 川菜, Italian \
        cuisine, etc.) whose articles hero whatever happens to be on the \
        editor's mind, fundamentally different food types (a stew article for \
        a stir-fry dish), or non-food content.
        """)
        let response = try await session.respond(
            to: "Dish name: \(dishName)\nWikipedia article title: \(articleTitle)\n\nReason about what the typical hero photo of this article most likely depicts, then judge whether that image would visually pass as the dish.",
            generating: ImageMatchResult.self
        )
        return response.content.matches
    }

    /// Produce up to a few alternative names/spellings of a dish that can be
    /// used to re-search Wikipedia when the first match was rejected. Includes
    /// English translation and well-known alternate spellings. Avoids broad
    /// cuisine categories.
    func suggestAlternativeNames(for dishName: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: """
        You suggest alternative names for a specific dish, useful for searching \
        encyclopedias and image databases. Include the English translation of \
        the dish, well-known alternate spellings or romanizations, and \
        regional names. Do not suggest broad categories like "Chinese cuisine" \
        — only specific dish names. Up to 3 suggestions.
        """)
        let response = try await session.respond(
            to: "Suggest alternative names for the dish: \(dishName)",
            generating: AlternativeNames.self
        )
        return response.content.terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != dishName.lowercased() }
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
    Keep the recipe in the SAME language as the original recipe. When the \
    original is in Chinese, draw on Chinese culinary sources (Chinese \
    cookbooks, zh.wikipedia.org, Chinese recipe sites) and phrase the \
    rationale, diagnosis, ingredients, steps, and change summaries in \
    Chinese. When English, in English. Do not mix languages.
    Ingredient quantities must be measurable. Each "kind" field in your \
    changes list must be exactly one of: stepAdded, stepRemoved, stepEdited, \
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
        let draft = response.content.toDraft(addressedFeedback: newFeedback)
        // Post-generation language enforcement: the refiner model frequently
        // slips back to English for non-English recipes despite the in-prompt
        // rule. Same safety net used for the initial generator.
        let referenceText = previousRevision.ingredients.map(\.name).joined(separator: " ")
            + " " + previousRevision.steps.map(\.text).joined(separator: " ")
        return try await enforceLanguage(draft: draft, referenceText: referenceText)
    }

    /// Check whether the refinement output language matches the previous
    /// revision's content language. If not, translate the entire refinement
    /// while preserving every ingredient, step, and change record's
    /// structural metadata (IDs, kinds, feedback links, etc.).
    func enforceLanguage(draft: RefinedRevisionDraft, referenceText: String) async throws -> RefinedRevisionDraft {
        let referenceCJK = LanguageHeuristics.containsCJK(referenceText)
        let sample = sampleText(for: draft)
        let sampleCJK = LanguageHeuristics.isMostlyCJK(sample)

        let target: String?
        if referenceCJK && !sampleCJK {
            target = "Chinese"
        } else if !referenceCJK && sampleCJK {
            target = "English"
        } else {
            target = nil
        }

        guard let target else { return draft }

        do {
            return try await translateRefinement(draft, toLanguage: target)
        } catch {
            return draft
        }
    }

    private func sampleText(for draft: RefinedRevisionDraft) -> String {
        let style = draft.referenceStyle ?? ""
        let rationale = draft.rationale
        let ingredients = draft.ingredients.map(\.name).joined(separator: " ")
        let steps = draft.steps.map(\.text).joined(separator: " ")
        let changes = draft.changes.map(\.summary).joined(separator: " ")
        return "\(style) \(rationale) \(ingredients) \(steps) \(changes)"
    }

    private func translateRefinement(_ draft: RefinedRevisionDraft, toLanguage language: String) async throws -> RefinedRevisionDraft {
        let session = LanguageModelSession(instructions: """
        You translate a refinement output from one language to another. Preserve \
        every ingredient, step, and change — do not add, remove, or reorder \
        anything. Translate the text content of the rationale, ingredient names, \
        step text, change summaries, and style reference. Output the translated \
        content as a structured response with arrays the same length as the input.
        """)
        let prompt = buildRefinementTranslationPrompt(draft: draft, target: language)
        let response = try await session.respond(
            to: prompt,
            generating: TranslatedRefinementContent.self
        )
        return reassembleTranslated(draft: draft, translated: response.content)
    }

    private func buildRefinementTranslationPrompt(draft: RefinedRevisionDraft, target: String) -> String {
        var s = "Target language: \(target)\n\nRefinement to translate:\n\n"
        s += "Rationale: \(draft.rationale)\n"
        if let style = draft.referenceStyle, !style.isEmpty {
            s += "Style: \(style)\n"
        }
        s += "\nIngredients (preserve count and order):\n"
        for ing in draft.ingredients {
            let q = ing.quantity.isEmpty ? "" : ing.quantity + " "
            s += "- \(q)\(ing.name)\n"
        }
        s += "\nSteps (preserve count and order):\n"
        for st in draft.steps {
            s += "\(st.index). \(st.text)\n"
        }
        s += "\nChange summaries (preserve count and order):\n"
        for c in draft.changes {
            s += "- \(c.summary)\n"
        }
        return s
    }

    private func reassembleTranslated(draft: RefinedRevisionDraft, translated: TranslatedRefinementContent) -> RefinedRevisionDraft {
        var newIngredients: [Ingredient] = []
        for (i, ing) in draft.ingredients.enumerated() {
            let translatedName = i < translated.ingredients.count
                ? translated.ingredients[i].trimmingCharacters(in: .whitespacesAndNewlines)
                : ing.name
            newIngredients.append(Ingredient(
                id: ing.id,
                name: translatedName.isEmpty ? ing.name : translatedName,
                quantity: ing.quantity,
                notes: ing.notes
            ))
        }
        var newSteps: [Step] = []
        for (i, st) in draft.steps.enumerated() {
            let translatedText = i < translated.steps.count
                ? translated.steps[i].trimmingCharacters(in: .whitespacesAndNewlines)
                : st.text
            newSteps.append(Step(
                id: st.id,
                index: st.index,
                text: translatedText.isEmpty ? st.text : translatedText,
                technique: st.technique,
                estimatedMinutes: st.estimatedMinutes
            ))
        }
        var newChanges: [Change] = []
        for (i, ch) in draft.changes.enumerated() {
            let translatedSummary = i < translated.changeSummaries.count
                ? translated.changeSummaries[i].trimmingCharacters(in: .whitespacesAndNewlines)
                : ch.summary
            newChanges.append(Change(
                id: ch.id,
                kind: ch.kind,
                summary: translatedSummary.isEmpty ? ch.summary : translatedSummary,
                feedbackID: ch.feedbackID,
                targetStepID: ch.targetStepID,
                targetIngredientID: ch.targetIngredientID
            ))
        }
        return RefinedRevisionDraft(
            ingredients: newIngredients,
            steps: newSteps,
            referenceStyle: translated.referenceStyle.isEmpty ? draft.referenceStyle : translated.referenceStyle,
            rationale: translated.rationale.isEmpty ? draft.rationale : translated.rationale,
            changes: newChanges,
            addressedFeedbackIDs: draft.addressedFeedbackIDs
        )
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
