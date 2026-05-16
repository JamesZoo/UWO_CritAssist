import SwiftUI

struct AddRecipeView: View {
    @Bindable var vm: AddRecipeViewModel
    var onCreated: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 宫爆鸡丁 or Kung Pao Chicken", text: $vm.dishName)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                } header: {
                    Text("Dish name")
                } footer: {
                    Text("That's all we need — the app will draft a starting recipe from public-source knowledge and fetch a representative photo.")
                }

                if let err = vm.errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { submit() }
                        .disabled(!vm.canSubmit)
                }
            }
            .overlay {
                if vm.isCreating {
                    ProgressView("Drafting recipe…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .interactiveDismissDisabled(vm.isCreating)
        }
    }

    private func submit() {
        Task {
            if let recipe = await vm.create() {
                onCreated(recipe)
                dismiss()
            }
        }
    }
}
