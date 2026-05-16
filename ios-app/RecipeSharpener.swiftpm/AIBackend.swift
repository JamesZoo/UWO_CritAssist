import Foundation

/// Bundle of AI services produced by an `AIBackendFactory`. The composition
/// root (`RootViewModel`) depends only on this struct and the protocols it
/// holds — it never names a concrete AI framework. Swap the factory to
/// swap the entire AI stack (Apple Intelligence today; a Claude-backed
/// implementation tomorrow).
///
/// Optional capabilities (`stepIllustrator`, `translator`, …) are nil when
/// the backend can't provide them. Composition is responsible for chaining
/// real-photo / fallback / validator services off these protocols.
struct AIBackend: Sendable {
    let kind: AIBackendKind
    let generator: RecipeGenerator
    let refiner: RecipeRefiner
    let brancher: VariationBrancher
    let finalizer: RecipeFinalizer
    let stepIllustrator: StepIllustrator?
    let profileImageGenerator: ProfileImageGenerator?
    let translator: RecipeTranslator?
    let imageMatchValidator: DishImageMatchValidator?
    let alternativeNameProvider: DishAlternativeNameProvider?
}

/// Factory abstraction for AI services. The composition root takes one of
/// these and never references a concrete AI framework directly. To wire a
/// different backend (Claude, OpenAI, an internal model gateway), implement
/// this protocol — no changes to view models, views, or any other service.
protocol AIBackendFactory: Sendable {
    func makeBackend() -> AIBackend
}

/// Returns a backend wired entirely from mocks. Used as the fallback when
/// no real AI is available on-device, and for snapshot / unit testing.
struct MockAIBackendFactory: AIBackendFactory {
    func makeBackend() -> AIBackend {
        AIBackend(
            kind: .mock,
            generator: MockRecipeGenerator(),
            refiner: MockRecipeRefiner(),
            brancher: MockVariationBrancher(),
            finalizer: MockRecipeFinalizer(),
            stepIllustrator: nil,
            profileImageGenerator: nil,
            translator: nil,
            imageMatchValidator: nil,
            alternativeNameProvider: nil
        )
    }
}
