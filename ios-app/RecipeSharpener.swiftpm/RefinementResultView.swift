import SwiftUI

struct RefinementResultView: View {
    let feedback: Feedback
    let previous: Revision
    let next: Revision
    var onDone: () -> Void = {}

    private var diff: RevisionDiff {
        RevisionDiffer.diff(from: previous, to: next)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                feedbackCard
                rationaleCard
                changesCard
                diffCard
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
        }
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

private struct StepDiffRow: View {
    let diff: StepDiff

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(symbol).font(.callout.monospaced()).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                if let b = diff.before, diff.kind == .removed {
                    Text(b.text).font(.callout).strikethrough()
                } else if let b = diff.before, let a = diff.after, diff.kind == .edited {
                    Text(b.text).font(.callout).strikethrough().foregroundStyle(.secondary)
                    Text(a.text).font(.callout)
                } else if let a = diff.after {
                    Text(a.text).font(.callout)
                }
                if diff.kind == .moved, let b = diff.before, let a = diff.after {
                    Text("step \(b.index) → \(a.index)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var symbol: String {
        switch diff.kind {
        case .added: return "＋"
        case .removed: return "－"
        case .edited: return "~"
        case .moved: return "↕"
        }
    }

    private var color: Color {
        switch diff.kind {
        case .added: return .green
        case .removed: return .red
        case .edited: return .orange
        case .moved: return .blue
        }
    }
}

private struct IngredientDiffRow: View {
    let diff: IngredientDiff

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(symbol).font(.callout.monospaced()).foregroundStyle(color)
            if let b = diff.before, diff.kind == .removed {
                Text("\(b.quantity) \(b.name)").strikethrough()
            } else if let b = diff.before, let a = diff.after, diff.kind == .edited {
                Text("\(b.quantity) \(b.name)").strikethrough().foregroundStyle(.secondary)
                Text("→ \(a.quantity) \(a.name)")
            } else if let a = diff.after {
                Text("\(a.quantity) \(a.name)")
            }
        }
        .font(.callout)
    }

    private var symbol: String {
        switch diff.kind {
        case .added: return "＋"
        case .removed: return "－"
        case .edited: return "~"
        }
    }

    private var color: Color {
        switch diff.kind {
        case .added: return .green
        case .removed: return .red
        case .edited: return .orange
        }
    }
}
