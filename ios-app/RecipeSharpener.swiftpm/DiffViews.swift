import SwiftUI

/// Reusable row views for displaying `RevisionDiff` output. Used by both
/// `RefinementResultView` (showing what a refinement changes vs. the prior
/// revision) and `VariationResultView` (showing what a variation changes
/// vs. the base recipe).
struct StepDiffRow: View {
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

struct IngredientDiffRow: View {
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
