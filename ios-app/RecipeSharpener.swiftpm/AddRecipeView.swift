import SwiftUI

struct AddRecipeView: View {
    @Bindable var vm: AddRecipeViewModel
    var onCreated: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                modePicker
                inputForMode
                if vm.mode != .dishName {
                    descriptionSection
                }
                if let err = vm.errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(vm.fallbackPromptShown ? Color.primary : Color.red)
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
            .onChange(of: vm.fallbackPromptShown) { _, newValue in
                if newValue && vm.mode == .dishName {
                    vm.mode = .pasteText
                }
            }
        }
    }

    private var modePicker: some View {
        Section {
            Picker("Source", selection: $vm.mode) {
                ForEach(AddRecipeViewModel.Mode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var inputForMode: some View {
        switch vm.mode {
        case .dishName:
            Section {
                TextField("e.g. 宫爆鸡丁 or Kung Pao Chicken", text: $vm.dishName)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { submit() }
            } header: {
                Text("Dish name")
            } footer: {
                Text("If we recognize the dish from public sources, we'll draft a starting recipe. If not, you'll be asked to paste your own or share a link.")
            }
        case .pasteText:
            Section {
                TextField("Paste recipe text here", text: $vm.pastedText, axis: .vertical)
                    .lineLimit(6...20)
                    .font(.callout)
            } header: {
                Text("Recipe text")
            } footer: {
                Text("Plain text with ingredients and steps (optionally with 'Ingredients:' and 'Steps:' headers). The app will normalize the structure.")
            }
        case .url:
            Section {
                TextField("https://…", text: $vm.urlString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            } header: {
                Text("Recipe URL")
            } footer: {
                Text("Link to a public recipe page; the app extracts ingredients and steps.")
            }
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField("e.g. Sichuan stir-fry, light and tingly", text: $vm.expectedDishDescription, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("What kind of dish do you expect?")
        } footer: {
            Text("Used to guide structure extraction and pick a representative image. Optional but helpful for secret-family-recipe scenarios.")
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
