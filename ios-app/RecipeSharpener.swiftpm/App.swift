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
    let images: RecipeImageService

    let listVM: RecipeListViewModel
    var addVM: AddRecipeViewModel?

    init() {
        let store = InMemoryRecipeStore(seed: PreviewSeed.recipes)
        let generator = MockRecipeGenerator()
        let images = MockRecipeImageService()
        self.store = store
        self.generator = generator
        self.images = images
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
}

struct RootView: View {
    @Bindable var rootVM: RootViewModel

    var body: some View {
        RecipeListView(
            vm: rootVM.listVM,
            onAddRecipe: { rootVM.startAdd() }
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
