import Foundation
import Observation

@Observable
@MainActor
final class AddRecipeViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case dishName
        case pasteText
        case url
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dishName: return "Dish name"
            case .pasteText: return "Paste recipe"
            case .url: return "Link"
            }
        }
    }

    private let generator: RecipeGenerator
    private let images: RecipeImageService
    private let clock: Clock

    var mode: Mode = .dishName
    var dishName: String = ""
    var pastedText: String = ""
    var urlString: String = ""
    var expectedDishDescription: String = ""
    var isCreating: Bool = false
    var errorMessage: String?
    var fallbackPromptShown: Bool = false

    init(generator: RecipeGenerator, images: RecipeImageService, clock: Clock = SystemClock()) {
        self.generator = generator
        self.images = images
        self.clock = clock
    }

    var canSubmit: Bool {
        guard !isCreating else { return false }
        switch mode {
        case .dishName:
            return !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pasteText:
            return !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .url:
            return URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.isEmpty == false
        }
    }

    func create() async -> Recipe? {
        isCreating = true
        defer { isCreating = false }
        errorMessage = nil

        do {
            let draft: InitialRecipeDraft
            let searchTermForImage: String

            switch mode {
            case .dishName:
                let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
                draft = try await generator.generateInitialRecipe(dishName: name)
                searchTermForImage = draft.name.isEmpty ? name : draft.name

            case .pasteText:
                let text = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = expectedDishDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                draft = try await generator.parseRecipe(fromText: text, expectedDish: desc.isEmpty ? nil : desc)
                searchTermForImage = desc.isEmpty ? draft.name : desc

            case .url:
                guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw RecipeGeneratorError.parsingFailed("Invalid URL")
                }
                let desc = expectedDishDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                draft = try await generator.parseRecipe(fromURL: url, expectedDish: desc.isEmpty ? nil : desc)
                searchTermForImage = desc.isEmpty ? draft.name : desc
            }

            let image: RecipeImageResult?
            if let importedURL = draft.imageURL {
                image = RecipeImageResult(
                    imageURL: importedURL,
                    attribution: draft.imageAttribution ?? ImageAttribution(sourceName: "Source URL")
                )
            } else {
                image = try? await images.fetchImage(for: searchTermForImage)
            }
            let firstRev = Revision(
                index: 1,
                createdAt: clock.now,
                ingredients: draft.ingredients,
                steps: draft.steps,
                referenceStyle: draft.referenceStyle,
                rationale: rationaleForMode(),
                changes: [],
                addressedFeedbackIDs: []
            )
            return Recipe(
                name: draft.name,
                summary: draft.summary,
                createdAt: clock.now,
                revisions: [firstRev],
                imageURL: image?.imageURL,
                imageAttribution: image?.attribution,
                sourceURL: draft.sourceURL,
                servings: draft.servings,
                prepMinutes: draft.prepMinutes,
                cookMinutes: draft.cookMinutes
            )
        } catch let RecipeGeneratorError.unknownDish(name) {
            fallbackPromptShown = true
            errorMessage = "No public recipe found for “\(name)”. Paste your own recipe or share a link to one below, and add a short description of what kind of dish to expect."
            return nil
        } catch let RecipeGeneratorError.safetyDeclined(name) {
            fallbackPromptShown = true
            errorMessage = "Apple Intelligence's safety filter declined to generate a recipe for “\(name)”. This is the on-device model's content policy, not a missing recipe — the dish exists and is well-known publicly. Paste your own recipe text or share a link to one below."
            return nil
        } catch {
            errorMessage = String(describing: error)
            return nil
        }
    }

    private func rationaleForMode() -> String {
        switch mode {
        case .dishName: return "Initial summary from public-source knowledge."
        case .pasteText: return "Initial recipe imported from pasted text."
        case .url: return "Initial recipe imported from URL."
        }
    }
}
