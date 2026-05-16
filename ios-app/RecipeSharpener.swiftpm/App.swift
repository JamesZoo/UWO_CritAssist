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
    var addVM: AddRecipeViewModel?
    var feedbackVM: FeedbackViewModel?
    var variationsVM: VariationsViewModel?
    var analysisVM: FinalAnalysisViewModel?

    init() {
        let store = InMemoryRecipeStore(seed: PreviewSeed.recipes)
        self.store = store
        self.generator = MockRecipeGenerator()
        self.refiner = MockRecipeRefiner()
        self.brancher = MockVariationBrancher()
        self.finalizer = MockRecipeFinalizer()
        self.images = MockRecipeImageService()
        self.listVM = RecipeListViewModel(store: store)
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
}

struct RootView: View {
    @Bindable var rootVM: RootViewModel

    var body: some View {
        RecipeListView(
            vm: rootVM.listVM,
            onAddRecipe: { rootVM.startAdd() },
            onCardFeedback: { rootVM.startFeedback(on: $0) },
            onCardVariations: { rootVM.startVariations(on: $0) },
            onCardAnalysis: { rootVM.startAnalysis(on: $0) }
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
    }
}

enum PreviewSeed {
    static var recipes: [Recipe] {
        let step1 = Step(index: 1, text: "Dice chicken and toss with cornstarch and a pinch of salt.", technique: "velveting")
        let step2 = Step(index: 2, text: "Mix sauce: vinegar, soy, sugar, water.")
        let step3 = Step(index: 3, text: "Sizzle chilies and peppercorns; stir-fry chicken; finish with sauce and peanuts.")
        let revision = Revision(
            index: 1,
            ingredients: [
                Ingredient(name: "Boneless chicken thigh", quantity: "300 g"),
                Ingredient(name: "Chinkiang vinegar", quantity: "2 tbsp"),
                Ingredient(name: "Dried red chilies", quantity: "8")
            ],
            steps: [step1, step2, step3],
            referenceStyle: "Sichuan home-style",
            rationale: "Initial summary from public Kung Pao recipes."
        )
        return [
            Recipe(
                name: "宫爆鸡丁",
                summary: "Classic Sichuan stir-fry: diced chicken with peanuts in a sweet-sour-spicy sauce.",
                revisions: [revision]
            )
        ]
    }
}
