import SwiftUI

struct VariationsView: View {
    @Bindable var vm: VariationsViewModel
    var onSaved: (Recipe) -> Void
    var onFeedbackOnVariation: (Recipe, UUID) -> Void = { _, _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Base recipe") {
                    Text(vm.recipe.name).font(.headline)
                    if let style = vm.recipe.currentRevision?.referenceStyle {
                        Text(style).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Variations") {
                    if vm.recipe.variations.isEmpty {
                        Text("No variations yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.recipe.variations) { variation in
                            variationRow(variation)
                        }
                    }
                }

                Section {
                    TextField("e.g. without chili, or extra spicy", text: $vm.directive, axis: .vertical)
                        .lineLimit(1...3)
                    Button {
                        Task {
                            if let updated = await vm.branch() {
                                onSaved(updated)
                            }
                        }
                    } label: {
                        if vm.isBranching {
                            HStack { ProgressView(); Text("Branching…") }
                        } else {
                            Text("Create variation")
                        }
                    }
                    .disabled(!vm.canBranch)
                } header: {
                    Text("New variation directive")
                } footer: {
                    Text("Branched from the current best base revision.")
                }

                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Variations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func variationRow(_ v: Variation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(v.name).font(.body.weight(.medium))
                Spacer()
                Text("rev \(v.currentRevision?.index ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !v.directive.isEmpty {
                Text(v.directive).font(.caption).foregroundStyle(.secondary)
            }
            if let r = v.currentRevision, !r.rationale.isEmpty {
                Text(r.rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Button {
                onFeedbackOnVariation(vm.recipe, v.id)
            } label: {
                Label("Give feedback on this variation", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)
        }
    }
}
