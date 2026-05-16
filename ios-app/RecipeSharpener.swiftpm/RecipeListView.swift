import SwiftUI

struct RecipeListView: View {
    @Bindable var vm: RecipeListViewModel
    var onAddRecipe: () -> Void = {}
    var onCardFeedback: (Recipe) -> Void = { _ in }
    var onCardVariations: (Recipe) -> Void = { _ in }
    var onCardAnalysis: (Recipe) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}

    @State private var pendingDelete: Recipe?

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
                        onGiveFeedback: { onCardFeedback(recipe) },
                        onOpenVariations: { onCardVariations(recipe) },
                        onOpenAnalysis: { onCardAnalysis(recipe) },
                        onDelete: { pendingDelete = recipe }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}
