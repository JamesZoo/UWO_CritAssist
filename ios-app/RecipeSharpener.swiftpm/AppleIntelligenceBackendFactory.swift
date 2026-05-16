import Foundation

/// Concrete `AIBackendFactory` backed by Apple Intelligence (FoundationModels
/// + ImagePlayground). Detects availability at runtime; falls through to a
/// mock backend on devices / simulators without on-device AI so the rest of
/// the app keeps working with placeholder content.
///
/// This is the ONLY type outside the `AppleIntelligence*` service files that
/// names the framework. Replace this factory at the composition root to
/// route every AI call through a different provider.
struct AppleIntelligenceBackendFactory: AIBackendFactory {
    let mockFallback: AIBackendFactory

    init(mockFallback: AIBackendFactory = MockAIBackendFactory()) {
        self.mockFallback = mockFallback
    }

    func makeBackend() -> AIBackend {
        guard AppleIntelligence.isAvailable else {
            return mockFallback.makeBackend()
        }
        let generator = AppleIntelligenceRecipeGenerator()
        let illustrator = AppleIntelligenceStepIllustrator()
        return AIBackend(
            kind: .onDevice,
            generator: generator,
            refiner: AppleIntelligenceRecipeRefiner(),
            brancher: AppleIntelligenceVariationBrancher(),
            finalizer: AppleIntelligenceRecipeFinalizer(),
            stepIllustrator: illustrator,
            profileImageGenerator: illustrator,
            translator: generator,
            imageMatchValidator: generator,
            alternativeNameProvider: generator
        )
    }
}

// MARK: - Protocol conformance for Apple Intelligence services
//
// Each concrete struct already has methods that match the auxiliary protocols
// in `AICapabilities.swift` — these extensions just declare conformance so
// the composition root can hold them behind the abstract types.

extension AppleIntelligenceRecipeGenerator: RecipeTranslator,
                                            DishImageMatchValidator,
                                            DishAlternativeNameProvider {}

extension AppleIntelligenceStepIllustrator: StepIllustrator,
                                            ProfileImageGenerator {}
