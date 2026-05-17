import SwiftUI

@main
struct RecipeSharpenerApp: App {
    @State private var rootVM = RootViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(rootVM: rootVM)
        }
    }
}

@Observable
@MainActor
final class RootViewModel {
    let store: RecipeStore
    let generator: RecipeGenerator
    let refiner: RecipeRefiner
    let brancher: VariationBrancher
    let finalizer: RecipeFinalizer
    let images: RecipeImageService
    let illustrator: StepIllustrator?

    let listVM: RecipeListViewModel
    let settingsVM: SettingsViewModel
    let trace: AITraceLog
    var addVM: AddRecipeViewModel?
    var feedbackVM: FeedbackViewModel?
    var variationsVM: VariationsViewModel?
    var analysisVM: FinalAnalysisViewModel?
    var settingsShown: Bool = false
    var illustratingRecipeIDs: Set<UUID> = []
    var refetchingRecipeIDs: Set<UUID> = []

    /// The composition root takes an `AIBackendFactory`, not a concrete AI
    /// implementation. Default is Apple Intelligence (with a mock fallback
    /// baked in for unsupported devices). Inject any other factory to swap
    /// the entire AI stack.
    init(aiFactory: AIBackendFactory = AppleIntelligenceBackendFactory()) {
        let trace = AITraceLog()
        let store: RecipeStore
        do {
            let fs = try FileSystemRecipeStore.localDocuments()
            Task.detached { try? await fs.seedIfEmpty(Fixtures.allScenarios) }
            store = fs
        } catch {
            store = InMemoryRecipeStore(seed: Fixtures.allScenarios)
        }
        self.store = store
        self.trace = trace

        let backend = aiFactory.makeBackend()

        // Wikipedia grounding is a generator-agnostic decorator that helps
        // any real AI avoid cultural-context drift (e.g. pork belly → 猪肚).
        // Skip it for the mock backend — feeding article text through the
        // mock's heuristic parser produces noise, not better recipes.
        let groundedGenerator: RecipeGenerator = backend.kind == .mock
            ? backend.generator
            : WikipediaGroundedRecipeGenerator(fallback: backend.generator)

        self.generator = TracedRecipeGenerator(
            inner: DefaultRecipeGenerator(fallback: groundedGenerator, translator: backend.translator),
            trace: trace,
            backend: backend.kind
        )
        self.refiner = TracedRecipeRefiner(inner: backend.refiner, trace: trace, backend: backend.kind)
        self.brancher = TracedVariationBrancher(inner: backend.brancher, trace: trace, backend: backend.kind)
        self.finalizer = TracedRecipeFinalizer(inner: backend.finalizer, trace: trace, backend: backend.kind)
        self.illustrator = backend.stepIllustrator

        self.images = FallbackImageService(
            primary: ValidatedImageService(
                base: WikimediaImageService(),
                validator: backend.imageMatchValidator,
                alternativeNameProvider: backend.alternativeNameProvider
            ),
            fallback: backend.profileImageGenerator
        )
        self.listVM = RecipeListViewModel(store: store)
        self.settingsVM = SettingsViewModel(store: store, trace: trace)
    }

    func startAdd() {
        addVM = AddRecipeViewModel(generator: generator, images: images)
    }

    func cancelAdd() { addVM = nil }

    func didCreate(_ recipe: Recipe) async {
        await listVM.upsert(recipe)
        addVM = nil
    }

    func startFeedback(on recipe: Recipe, variationID: UUID? = nil) {
        feedbackVM = FeedbackViewModel(refiner: refiner, recipe: recipe, variationID: variationID)
    }

    func cancelFeedback() { feedbackVM = nil }

    func didRefine(_ recipe: Recipe) async {
        await listVM.upsert(recipe)
        feedbackVM = nil
    }

    func startVariations(on recipe: Recipe) {
        variationsVM = VariationsViewModel(brancher: brancher, recipe: recipe)
    }

    func cancelVariations() { variationsVM = nil }

    func didUpdateVariations(_ recipe: Recipe) async {
        await listVM.upsert(recipe)
        if variationsVM?.recipe.id == recipe.id {
            variationsVM?.recipe = recipe
        }
    }

    func startAnalysis(on recipe: Recipe) {
        analysisVM = FinalAnalysisViewModel(finalizer: finalizer, recipe: recipe)
    }

    func cancelAnalysis() { analysisVM = nil }

    func openSettings() { settingsShown = true }
    func closeSettings() { settingsShown = false }

    /// Re-run the image service for an existing recipe and replace the
    /// recipe's profile photo. Useful when the current photo is wrong or
    /// the user wants a different illustration on the AI-generation path.
    func refetchImage(for recipe: Recipe) async {
        refetchingRecipeIDs.insert(recipe.id)
        defer { refetchingRecipeIDs.remove(recipe.id) }
        guard let result = try? await images.fetchImage(for: recipe.name) else {
            return
        }
        var updated = recipe
        updated.imageURL = result.imageURL
        updated.imageAttribution = result.attribution
        await listVM.upsert(updated)
    }

    func undoLastRefinement(on recipe: Recipe) async {
        guard recipe.revisions.count > 1 else { return }
        // The refiner's per-recipe session memory no longer matches the
        // recipe's actual state — reset so the next refine() starts fresh.
        await refiner.resetContext(for: recipe.id)
        var updated = recipe
        let popped = updated.revisions.removeLast()
        let addressedIDs = Set(popped.addressedFeedbackIDs)
        if !addressedIDs.isEmpty {
            updated.feedback.removeAll { addressedIDs.contains($0.id) }
        }
        await listVM.upsert(updated)
    }

    func illustrate(recipe: Recipe) async {
        guard let illustrator else { return }
        guard let currentRevision = recipe.currentRevision else { return }
        illustratingRecipeIDs.insert(recipe.id)
        defer { illustratingRecipeIDs.remove(recipe.id) }

        // Clear any previously stored step images (e.g. old AI-generated PNGs)
        // before running the Wikipedia fetch so stale images never persist.
        var working = recipe
        let revisionIdx = working.revisions.count - 1
        for i in working.revisions[revisionIdx].steps.indices {
            working.revisions[revisionIdx].steps[i].imageURL = nil
        }
        await listVM.upsert(working)

        let stepImages: [(stepIndex: Int, imageURL: URL)]
        do {
            stepImages = try await illustrator.illustrateSteps(in: currentRevision, dishName: recipe.name)
        } catch {
            return
        }
        guard !stepImages.isEmpty else { return }

        for (stepIndex, url) in stepImages {
            if let stepIdx = working.revisions[revisionIdx].steps.firstIndex(where: { $0.index == stepIndex }) {
                working.revisions[revisionIdx].steps[stepIdx].imageURL = url
                await listVM.upsert(working)
            }
        }
    }
}

struct RootView: View {
    @Bindable var rootVM: RootViewModel

    var body: some View {
        RecipeListView(
            vm: rootVM.listVM,
            onAddRecipe: { rootVM.startAdd() },
            onCardFeedback: { rootVM.startFeedback(on: $0) },
            onCardVariations: { rootVM.startVariations(on: $0) },
            onCardAnalysis: { rootVM.startAnalysis(on: $0) },
            onCardIllustrate: { recipe in
                Task { await rootVM.illustrate(recipe: recipe) }
            },
            onCardRefetchImage: { recipe in
                Task { await rootVM.refetchImage(for: recipe) }
            },
            onOpenSettings: { rootVM.openSettings() },
            onUndoLastRefinement: { recipe in
                Task { await rootVM.undoLastRefinement(on: recipe) }
            },
            canIllustrate: rootVM.illustrator != nil,
            illustratingRecipeIDs: rootVM.illustratingRecipeIDs,
            refetchingRecipeIDs: rootVM.refetchingRecipeIDs
        )
        .sheet(isPresented: Binding(
            get: { rootVM.addVM != nil },
            set: { if !$0 { rootVM.cancelAdd() } }
        )) {
            if let vm = rootVM.addVM {
                AddRecipeView(vm: vm) { recipe in
                    Task { await rootVM.didCreate(recipe) }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { rootVM.feedbackVM != nil },
            set: { if !$0 { rootVM.cancelFeedback() } }
        )) {
            if let vm = rootVM.feedbackVM {
                FeedbackSheet(vm: vm) { recipe in
                    Task { await rootVM.didRefine(recipe) }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { rootVM.variationsVM != nil },
            set: { if !$0 { rootVM.cancelVariations() } }
        )) {
            if let vm = rootVM.variationsVM {
                VariationsView(vm: vm) { updated in
                    Task { await rootVM.didUpdateVariations(updated) }
                } onFeedbackOnVariation: { recipe, vid in
                    rootVM.cancelVariations()
                    rootVM.startFeedback(on: recipe, variationID: vid)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { rootVM.analysisVM != nil },
            set: { if !$0 { rootVM.cancelAnalysis() } }
        )) {
            if let vm = rootVM.analysisVM {
                FinalAnalysisView(vm: vm)
            }
        }
        .sheet(isPresented: Binding(
            get: { rootVM.settingsShown },
            set: { if !$0 { rootVM.closeSettings() } }
        )) {
            SettingsView(vm: rootVM.settingsVM) { _ in
                // AI backend swap is wired in commit 15 when real services exist.
            } onListNeedsRefresh: {
                Task { await rootVM.listVM.load() }
            }
        }
    }
}

