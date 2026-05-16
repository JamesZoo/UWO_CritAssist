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

    let listVM: RecipeListViewModel
    let settingsVM: SettingsViewModel
    let trace: AITraceLog
    var addVM: AddRecipeViewModel?
    var feedbackVM: FeedbackViewModel?
    var variationsVM: VariationsViewModel?
    var analysisVM: FinalAnalysisViewModel?
    var settingsShown: Bool = false

    init() {
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

        let aiAvailable = AppleIntelligence.isAvailable
        let realGenerator: RecipeGenerator = aiAvailable
            ? AppleIntelligenceRecipeGenerator()
            : MockRecipeGenerator()
        let realRefiner: RecipeRefiner = aiAvailable
            ? AppleIntelligenceRecipeRefiner()
            : MockRecipeRefiner()
        let aiBackend: AIBackendKind = aiAvailable ? .onDevice : .mock

        self.generator = TracedRecipeGenerator(
            inner: DefaultRecipeGenerator(fallback: realGenerator),
            trace: trace,
            backend: aiBackend
        )
        self.refiner = TracedRecipeRefiner(inner: realRefiner, trace: trace, backend: aiBackend)
        self.brancher = TracedVariationBrancher(inner: MockVariationBrancher(), trace: trace, backend: .mock)
        self.finalizer = TracedRecipeFinalizer(inner: MockRecipeFinalizer(), trace: trace, backend: .mock)
        self.images = MockRecipeImageService()
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

    func undoLastRefinement(on recipe: Recipe) async {
        guard recipe.revisions.count > 1 else { return }
        var updated = recipe
        let popped = updated.revisions.removeLast()
        let addressedIDs = Set(popped.addressedFeedbackIDs)
        if !addressedIDs.isEmpty {
            updated.feedback.removeAll { addressedIDs.contains($0.id) }
        }
        await listVM.upsert(updated)
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
            onOpenSettings: { rootVM.openSettings() },
            onUndoLastRefinement: { recipe in
                Task { await rootVM.undoLastRefinement(on: recipe) }
            }
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

