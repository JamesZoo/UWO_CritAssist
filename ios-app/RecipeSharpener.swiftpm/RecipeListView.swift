import SwiftUI

struct RecipeListView: View {
    @Bindable var vm: RecipeListViewModel
    var onAddRecipe: () -> Void = {}
    var onCardFeedback: (Recipe) -> Void = { _ in }
    var onCardVariations: (Recipe) -> Void = { _ in }
    var onCardAnalysis: (Recipe) -> Void = { _ in }
    var onCardIllustrate: (Recipe) -> Void = { _ in }
    var onCardClearIllustrations: (Recipe) -> Void = { _ in }
    var onCardRefetchImage: (Recipe) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onUndoLastRefinement: (Recipe) -> Void = { _ in }
    var canIllustrate: Bool = false
    var illustratingRecipeIDs: Set<UUID> = []
    var refetchingRecipeIDs: Set<UUID> = []

    @State private var pendingDelete: Recipe?
    @State private var pendingUndo: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.recipes.isEmpty {
                    ProgressView("Loading recipes…")
                } else if vm.displayed.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Recipe Sharpener")
            .searchable(text: $vm.query, prompt: Text("Search dish, ingredient, step"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onAddRecipe()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .overlay(alignment: .bottom) {
                if let msg = vm.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .padding(8)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
            .alert(
                "Delete \"\(pendingDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { recipe in
                Button("Delete", role: .destructive) {
                    Task { await vm.delete(recipe) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { _ in
                Text("This permanently removes the recipe, its revisions, feedback, and variations.")
            }
            .alert(
                "Undo last refinement of \"\(pendingUndo?.name ?? "")\"?",
                isPresented: Binding(
                    get: { pendingUndo != nil },
                    set: { if !$0 { pendingUndo = nil } }
                ),
                presenting: pendingUndo
            ) { recipe in
                Button("Undo", role: .destructive) {
                    onUndoLastRefinement(recipe)
                    pendingUndo = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingUndo = nil
                }
            } message: { recipe in
                let count = recipe.revisions.count
                Text("Rolls back to revision \(max(count - 1, 1)). The most recent revision and the feedback that drove it will be removed.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No recipes yet", systemImage: "fork.knife.circle")
        } description: {
            Text("Tap + to start one from just a dish name.")
        } actions: {
            Button("Add a recipe") { onAddRecipe() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(vm.displayed) { recipe in
                    RecipeCardView(
                        recipe: recipe,
                        isIllustrating: illustratingRecipeIDs.contains(recipe.id),
                        isRefetchingImage: refetchingRecipeIDs.contains(recipe.id),
                        canIllustrate: canIllustrate,
                        onGiveFeedback: { onCardFeedback(recipe) },
                        onOpenVariations: { onCardVariations(recipe) },
                        onOpenAnalysis: { onCardAnalysis(recipe) },
                        onIllustrate: { onCardIllustrate(recipe) },
                        onClearIllustrations: { onCardClearIllustrations(recipe) },
                        onRefetchImage: { onCardRefetchImage(recipe) },
                        onDelete: { pendingDelete = recipe },
                        onUndoLastRefinement: { pendingUndo = recipe }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}
