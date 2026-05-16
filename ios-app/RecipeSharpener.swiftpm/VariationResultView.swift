import SwiftUI

/// Approval gate for a newly-generated variation. Shows what's different
/// from the base recipe — model-reported changes plus the ground-truth
/// structural diff — so the user can Apply or Discard before the variation
/// is saved into the recipe.
struct VariationResultView: View {
    let variation: Variation
    let baseRevision: Revision
    var onApply: () -> Void = {}
    var onDiscard: () -> Void = {}

    private var diff: RevisionDiff {
        guard let firstRev = variation.revisions.first else {
            return RevisionDiff(stepDiffs: [], ingredientDiffs: [])
        }
        return RevisionDiffer.diff(from: baseRevision, to: firstRev)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pendingNotice
                headerCard
                rationaleCard
                changesCard
                diffCard
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    onApply()
                } label: {
                    Text("Apply variation")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(role: .cancel) {
                    onDiscard()
                } label: {
                    Text("Discard — variation not added")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.regularMaterial)
        }
    }

    private var pendingNotice: some View {
        Text("Review the proposed variation. Nothing is saved until you tap Apply.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Variation").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(variation.name).font(.title3.weight(.semibold))
            if !variation.directive.isEmpty {
                Text("Directive: \(variation.directive)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var rationaleCard: some View {
        if let rev = variation.revisions.first, !rev.rationale.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Rationale")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(rev.rationale).font(.callout)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var changesCard: some View {
        if let rev = variation.revisions.first, !rev.changes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model-reported changes vs. base")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(rev.changes) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(for: change.kind))
                            .foregroundStyle(.tint)
                        Text(change.summary).font(.callout)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var diffCard: some View {
        if !diff.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Structural diff (base → variation)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !diff.ingredientDiffs.isEmpty {
                    Text("Ingredients").font(.caption).foregroundStyle(.secondary)
                    ForEach(diff.ingredientDiffs, id: \.self) { d in
                        IngredientDiffRow(diff: d)
                    }
                }
                if !diff.stepDiffs.isEmpty {
                    Text("Steps").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(diff.stepDiffs, id: \.self) { d in
                        StepDiffRow(diff: d)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.gray.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
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
