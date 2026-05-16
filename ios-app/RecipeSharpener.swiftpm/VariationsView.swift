import SwiftUI

struct VariationsView: View {
    @Bindable var vm: VariationsViewModel
    var onSaved: (Recipe) -> Void
    var onFeedbackOnVariation: (Recipe, UUID) -> Void = { _, _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let pending = vm.pendingVariation, let base = vm.branchSource?.revision {
                    VariationResultView(
                        variation: pending,
                        baseRevision: base,
                        onApply: {
                            if let updated = vm.apply() {
                                onSaved(updated)
                            }
                        },
                        onDiscard: {
                            vm.discard()
                        }
                    )
                } else {
                    listForm
                }
            }
            .navigationTitle(vm.pendingVariation == nil ? "Variations" : "New variation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.pendingVariation == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private var listForm: some View {
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
                if !vm.recipe.variations.isEmpty {
                    branchSourcePicker
                }
                TextField("e.g. without chili, or extra spicy", text: $vm.directive, axis: .vertical)
                    .lineLimit(1...3)
                Button {
                    Task { await vm.generate() }
                } label: {
                    if vm.isBranching {
                        HStack { ProgressView(); Text("Generating proposal…") }
                    } else {
                        Text("Propose variation")
                    }
                }
                .disabled(!vm.canBranch)
            } header: {
                Text("New variation directive")
            } footer: {
                Text("AI proposes changes from the chosen branch source. You review and choose Apply or Discard.")
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.footnote) }
            }
        }
    }

    private var branchSourcePicker: some View {
        Menu {
            Button {
                vm.branchFromVariationID = nil
            } label: {
                HStack {
                    Text("\(vm.recipe.name) (base)")
                    if vm.branchFromVariationID == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            ForEach(vm.recipe.variations) { v in
                Button {
                    vm.branchFromVariationID = v.id
                } label: {
                    HStack {
                        Text(v.name)
                        if vm.branchFromVariationID == v.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Branch from")
                Spacer()
                Text(vm.branchSourceLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func variationRow(_ v: Variation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
                Text(r.rationale).font(.caption).foregroundStyle(.secondary)
            }
            if let r = v.currentRevision, !r.changes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(r.changes) { c in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: icon(for: c.kind)).font(.caption2)
                            Text(c.summary).font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
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

    private func icon(for kind: ChangeKind) -> String {
        switch kind {
        case .stepAdded, .ingredientAdded: return "plus.circle"
        case .stepRemoved, .ingredientRemoved: return "minus.circle"
        case .stepEdited, .ingredientEdited: return "pencil.circle"
        case .techniqueChanged: return "arrow.triangle.swap"
        }
    }
}
