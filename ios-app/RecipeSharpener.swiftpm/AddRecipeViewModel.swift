import Foundation
import Observation

@Observable
@MainActor
final class AddRecipeViewModel {
    private let generator: RecipeGenerator
    private let images: RecipeImageService
    private let clock: Clock

    var dishName: String = ""
    var isCreating: Bool = false
    var errorMessage: String?

    init(generator: RecipeGenerator, images: RecipeImageService, clock: Clock = SystemClock()) {
        self.generator = generator
        self.images = images
        self.clock = clock
    }

    var canSubmit: Bool {
        !isCreating && !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func create() async -> Recipe? {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        isCreating = true
        defer { isCreating = false }
        do {
            async let draftTask = generator.generateInitialRecipe(dishName: name)
            async let imageTask = images.fetchImage(for: name)
            let draft = try await draftTask
            let image = try await imageTask

            let firstRevision = Revision(
                index: 1,
                createdAt: clock.now,
                ingredients: draft.ingredients,
                steps: draft.steps,
                referenceStyle: draft.referenceStyle,
                rationale: "Initial summary from public recipes.",
                changes: [],
                addressedFeedbackIDs: []
            )

            return Recipe(
                name: draft.name.isEmpty ? name : draft.name,
                summary: draft.summary,
                createdAt: clock.now,
                revisions: [firstRevision],
                variations: [],
                feedback: [],
                imageURL: image?.imageURL,
                imageAttribution: image?.attribution
            )
        } catch {
            errorMessage = String(describing: error)
            return nil
        }
    }
}
