import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var isIllustrating: Bool = false
    var canIllustrate: Bool = true
    var onGiveFeedback: () -> Void = {}
    var onOpenVariations: () -> Void = {}
    var onOpenAnalysis: () -> Void = {}
    var onIllustrate: () -> Void = {}
    var onDelete: () -> Void = {}
    var onUndoLastRefinement: () -> Void = {}

    @State private var descriptionExpanded = false
    @State private var stepsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            collapsibleSummary
            recentImprovement
            stepsSection
            footerButtons
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            if recipe.revisions.count > 1 {
                Button {
                    onUndoLastRefinement()
                } label: {
                    Label("Undo last refinement", systemImage: "arrow.uturn.backward")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete recipe", systemImage: "trash")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if let style = recipe.currentRevision?.referenceStyle, !style.isEmpty {
                    Text(style)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                attributionChip
            }
            Spacer(minLength: 0)
        }
    }

    private var thumbnail: some View {
        Group {
            if let url = recipe.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholderThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private var attributionChip: some View {
        if let attr = recipe.imageAttribution {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("\(attr.sourceName)\(attr.licenseName.map { " · \($0)" } ?? "")")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
    }

    private var collapsibleSummary: some View {
        DisclosureGroup(isExpanded: $descriptionExpanded) {
            Text(recipe.summary.isEmpty ? "No description yet." : recipe.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Text("Description")
                .font(.subheadline.weight(.medium))
        }
    }

    @ViewBuilder
    private var recentImprovement: some View {
        if let latest = recipe.currentRevision, !latest.rationale.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Last improvement")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(latest.rationale)
                    .font(.callout)
                Button {
                    onGiveFeedback()
                } label: {
                    Label("Give feedback", systemImage: "bubble.left.and.text.bubble.right")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        } else {
            Button {
                onGiveFeedback()
            } label: {
                Label("Give first feedback", systemImage: "bubble.left.and.text.bubble.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var stepsSection: some View {
        DisclosureGroup(isExpanded: $stepsExpanded) {
            if let steps = recipe.currentRevision?.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }
                .padding(.top, 4)
            } else {
                Text("No steps yet.").font(.callout).foregroundStyle(.secondary)
            }
        } label: {
            Text("Current steps")
                .font(.subheadline.weight(.medium))
        }
    }

    private func stepRow(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(step.index).")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(step.text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let url = step.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .frame(maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 8) {
            Button {
                onOpenVariations()
            } label: {
                Label("Variations (\(recipe.variations.count))", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if canIllustrate {
                Button {
                    onIllustrate()
                } label: {
                    if isIllustrating {
                        HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("Illustrating…") }
                    } else {
                        Label("Illustrate", systemImage: "photo.on.rectangle.angled")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isIllustrating)
            }

            Button {
                onOpenAnalysis()
            } label: {
                Label("Analysis", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
