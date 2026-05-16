import SwiftUI

struct RefinementResultView: View {
    let feedback: Feedback
    let previous: Revision
    let next: Revision
    var onApply: () -> Void = {}
    var onDiscard: () -> Void = {}

    private var diff: RevisionDiff {
        RevisionDiffer.diff(from: previous, to: next)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pendingNotice
                feedbackCard
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
                    Text("Apply this refinement")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(role: .cancel) {
                    onDiscard()
                } label: {
                    Text("Discard — recipe unchanged")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.regularMaterial)
        }
    }

    private var pendingNotice: some View {
        Text("Review the proposed refinement. Nothing is saved until you tap Apply.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your feedback").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(feedback.text).font(.callout)
            if let rating = feedback.rating {
                Text("Rating: \(rating)/5").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rationaleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Refinement rationale")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(next.rationale.isEmpty ? "(no rationale)" : next.rationale)
                .font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var changesCard: some View {
        if !next.changes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model-reported changes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(next.changes) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(for: change.kind))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.summary).font(.callout)
                            if change.feedbackID == feedback.id {
                                Text("← caused by your feedback")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                Text("Structural diff (rev \(previous.index) → \(next.index))")
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

